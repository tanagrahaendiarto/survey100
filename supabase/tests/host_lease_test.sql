-- Host lease behaviour: a signed-in Host keeps working even when its lease
-- lapsed, while a different Host can never steal a live lease.
begin;

create extension if not exists pgtap with schema extensions;
select plan(7);

delete from public.host_lease where singleton;
delete from public.host_sessions
where token_hash in (repeat('c', 64), repeat('d', 64));

insert into public.host_sessions(token_hash, expires_at)
values (repeat('c', 64), now() + interval '1 hour');

select ok(
  public.host_session_is_active(repeat('c', 64)),
  'signed-in Host can read game state without holding a lease'
);

select lives_ok(
  $$select public.heartbeat_host_lease(repeat('c', 64))$$,
  'heartbeat claims a free lease'
);
select is(
  (select token_hash from public.host_lease where singleton),
  repeat('c', 64),
  'lease belongs to the signed-in Host'
);

update public.host_lease
set expires_at = now() - interval '1 minute'
where singleton;

select lives_ok(
  $$select public.heartbeat_host_lease(repeat('c', 64))$$,
  'heartbeat reclaims its own lapsed lease instead of forcing a login'
);
select ok(
  (select expires_at from public.host_lease where singleton) > now() + interval '4 minutes',
  'renewed lease outlives browser timer throttling'
);

insert into public.host_sessions(token_hash, expires_at)
values (repeat('d', 64), now() + interval '1 hour');

select throws_ok(
  $$select public.heartbeat_host_lease(repeat('d', 64))$$,
  'P0001', 'HOST_LEASE_EXPIRED',
  'another Host cannot steal a live lease'
);

update public.host_sessions
set expires_at = now() - interval '1 minute'
where token_hash = repeat('c', 64);

select throws_ok(
  $$select public.heartbeat_host_lease(repeat('c', 64))$$,
  'P0001', 'HOST_LEASE_EXPIRED',
  'logged-out or taken-over session cannot reclaim the lease'
);

select * from finish();
rollback;
