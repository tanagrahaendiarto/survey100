-- Host no longer gets logged out by itself.
--
-- Reading Host state now only needs a live session (8 hours), not a live
-- lease, so a Realtime refresh can never kick the operator out. The lease
-- still decides who may mutate the game, but it is reclaimed by the same
-- session that owns it instead of forcing a fresh login, and it lasts long
-- enough to survive browser timer throttling and short sleep/offline gaps.
create or replace function public.host_session_is_active(p_token_hash text)
returns boolean
language sql
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.host_sessions s
    where s.token_hash = p_token_hash
      and s.expires_at > clock_timestamp()
  );
$$;

create or replace function public.acquire_host_lease(p_token_hash text, p_takeover boolean)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_lease public.host_lease%rowtype;
  v_now timestamptz := clock_timestamp();
  v_expires_at timestamptz := clock_timestamp() + interval '5 minutes';
begin
  if p_token_hash is null or p_token_hash !~ '^[a-f0-9]{64}$' then
    raise exception using message = 'INVALID_SESSION_TOKEN';
  end if;

  perform 1 from public.game_state where singleton for update;
  if not found then
    raise exception using message = 'GAME_NOT_INITIALIZED';
  end if;

  select * into v_lease from public.host_lease where singleton for update;

  if found and v_lease.expires_at > v_now and p_takeover is distinct from true then
    return jsonb_build_object('ok', false, 'reason', 'HOST_IN_USE');
  end if;

  if found then
    update public.host_sessions
    set expires_at = v_now
    where token_hash = v_lease.token_hash;
  end if;

  insert into public.host_sessions(token_hash, expires_at)
  values (p_token_hash, v_now + interval '8 hours');

  insert into public.host_lease(singleton, token_hash, expires_at)
  values (true, p_token_hash, v_expires_at)
  on conflict (singleton) do update
  set token_hash = excluded.token_hash,
      expires_at = excluded.expires_at;

  return jsonb_build_object('ok', true, 'expiresAt', v_expires_at);
end;
$$;

-- Extends the lease, and takes it back when it lapsed while this session was
-- still signed in (background tab, sleep, network gap). A takeover by another
-- Host expires this session, so it can no longer reclaim anything.
create or replace function public.heartbeat_host_lease(p_token_hash text)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_lease public.host_lease%rowtype;
  v_expires_at timestamptz := clock_timestamp() + interval '5 minutes';
begin
  if p_token_hash is null or p_token_hash !~ '^[a-f0-9]{64}$' then
    raise exception using message = 'INVALID_SESSION_TOKEN';
  end if;

  perform 1 from public.game_state where singleton for update;
  if not found then
    raise exception using message = 'GAME_NOT_INITIALIZED';
  end if;

  if not exists (
    select 1
    from public.host_sessions s
    where s.token_hash = p_token_hash
      and s.expires_at > v_now
  ) then
    raise exception using message = 'HOST_LEASE_EXPIRED';
  end if;

  select * into v_lease from public.host_lease where singleton for update;

  if found and v_lease.token_hash <> p_token_hash and v_lease.expires_at > v_now then
    raise exception using message = 'HOST_LEASE_EXPIRED';
  end if;

  insert into public.host_lease(singleton, token_hash, expires_at)
  values (true, p_token_hash, v_expires_at)
  on conflict (singleton) do update
  set token_hash = excluded.token_hash,
      expires_at = excluded.expires_at;

  return v_expires_at;
end;
$$;

revoke execute on function public.host_session_is_active(text) from public, anon, authenticated;
revoke execute on function public.acquire_host_lease(text, boolean) from public, anon, authenticated;
revoke execute on function public.heartbeat_host_lease(text) from public, anon, authenticated;

grant execute on function public.host_session_is_active(text) to service_role;
grant execute on function public.acquire_host_lease(text, boolean) to service_role;
grant execute on function public.heartbeat_host_lease(text) to service_role;

notify pgrst, 'reload schema';
