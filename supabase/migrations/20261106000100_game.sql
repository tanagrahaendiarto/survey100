create table public.questions (
  id text primary key,
  position smallint not null unique check (position between 1 and 3),
  title text not null,
  content_verified boolean not null default false
);

create table public.answers (
  id text primary key,
  question_id text not null references public.questions(id) on delete cascade,
  position smallint not null check (position between 1 and 5),
  answer_text text not null,
  points integer not null check (points > 0),
  unique (question_id, position),
  unique (id, question_id)
);

create table public.game_state (
  singleton boolean primary key default true check (singleton),
  status text not null default 'READY'
    check (status in ('READY', 'IN_PROGRESS', 'COMPLETED')),
  active_question_id text not null references public.questions(id),
  version bigint not null default 0 check (version >= 0),
  updated_at timestamptz not null default now()
);

create sequence public.game_action_order_seq;

create table public.game_actions (
  action_id uuid primary key,
  action_order bigint not null default nextval('public.game_action_order_seq'),
  undo_order bigint,
  question_id text not null references public.questions(id),
  answer_id text not null,
  answer_position smallint not null check (answer_position between 1 and 5),
  answer_text text not null,
  points_awarded integer not null check (points_awarded > 0),
  team text not null check (team in ('A', 'B')),
  status text not null default 'applied'
    check (status in ('applied', 'undone', 'discarded')),
  created_at timestamptz not null default now(),
  foreign key (answer_id, question_id)
    references public.answers(id, question_id)
);

create index game_actions_question_status_order
  on public.game_actions(question_id, status, action_order desc);

create table public.revealed_answers (
  question_id text not null references public.questions(id),
  answer_id text not null,
  answer_position smallint not null check (answer_position between 1 and 5),
  answer_text text not null,
  points_awarded integer not null check (points_awarded > 0),
  team text not null check (team in ('A', 'B')),
  action_id uuid not null unique references public.game_actions(action_id),
  opened_at timestamptz not null default now(),
  primary key (question_id, answer_id),
  foreign key (answer_id, question_id)
    references public.answers(id, question_id)
);

create table public.game_requests (
  request_id uuid primary key,
  request_payload jsonb not null,
  created_at timestamptz not null default now()
);

create table public.host_sessions (
  token_hash text primary key check (token_hash ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.host_lease (
  singleton boolean primary key default true check (singleton),
  token_hash text not null references public.host_sessions(token_hash),
  expires_at timestamptz not null
);

create table public.host_login_attempts (
  key_hash text primary key check (key_hash ~ '^[a-f0-9]{64}$'),
  attempts smallint not null default 0,
  window_started_at timestamptz not null default now(),
  blocked_until timestamptz
);

insert into public.questions(id, position, title, content_verified)
values
  ('q1', 1, 'Apa alasan paling umum mahasiswa datang terlambat ke kelas?', false),
  ('q2', 2, 'Apa alasan mahasiswa memilih duduk di bagian belakang kelas?', false),
  ('q3', 3, '', false);

-- Poin berikut adalah contoh PRD dan belum diverifikasi sebagai hasil survei.
insert into public.answers(id, question_id, position, answer_text, points)
values
  ('q1-a1', 'q1', 1, 'Bangun kesiangan', 50),
  ('q1-a2', 'q1', 2, 'Macet', 30),
  ('q1-a3', 'q1', 3, 'Begadang mengerjakan tugas', 20),
  ('q1-a4', 'q1', 4, 'Terlambat bersiap-siap', 15),
  ('q1-a5', 'q1', 5, 'Jarak tempat tinggal ke kelas jauh', 5),
  ('q2-a1', 'q2', 1, 'Bisa bermain HP', 50),
  ('q2-a2', 'q2', 2, 'Bisa tidur tanpa ketahuan', 30),
  ('q2-a3', 'q2', 3, 'Menghindari pertanyaan dosen', 20),
  ('q2-a4', 'q2', 4, 'Lebih bebas mengobrol', 15),
  ('q2-a5', 'q2', 5, 'Lebih nyaman dan santai', 5);

insert into public.game_state(singleton, status, active_question_id)
values (true, 'READY', 'q1');

alter table public.questions enable row level security;
alter table public.answers enable row level security;
alter table public.game_state enable row level security;
alter table public.game_actions enable row level security;
alter table public.revealed_answers enable row level security;
alter table public.game_requests enable row level security;
alter table public.host_sessions enable row level security;
alter table public.host_lease enable row level security;
alter table public.host_login_attempts enable row level security;

revoke all on table
  public.questions, public.answers, public.game_state, public.game_actions,
  public.revealed_answers, public.game_requests, public.host_sessions,
  public.host_lease, public.host_login_attempts
  from public, anon, authenticated, service_role;
revoke all on sequence public.game_action_order_seq from public, anon, authenticated, service_role;

grant usage on schema public to anon, service_role;
grant select on public.game_state, public.revealed_answers to anon;
create policy display_reads_game_state on public.game_state
  for select to anon using (true);
create policy display_reads_revealed_answers on public.revealed_answers
  for select to anon using (true);
create policy display_receives_game_events on realtime.messages
  for select to anon using (topic = 'top-survey:main');
create policy display_active_question_only on public.revealed_answers
  as restrictive for select to anon
  using (question_id = (select active_question_id from public.game_state where singleton));

grant select on table public.questions, public.answers to service_role;
grant select, update on table public.game_state to service_role;
grant select, insert, update, delete on table public.game_actions to service_role;
grant select, insert, delete on table public.revealed_answers to service_role;
grant select, insert on table public.game_requests to service_role;
grant select, insert, update on table public.host_sessions to service_role;
grant select, insert, update, delete on table public.host_lease to service_role;
grant select, insert, update, delete on table public.host_login_attempts to service_role;
grant usage on sequence public.game_action_order_seq to service_role;

create function public.game_snapshot()
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'status', g.status,
    'activeQuestionId', g.active_question_id,
    'version', g.version,
    'scores', jsonb_build_object(
      'A', coalesce((select sum(points_awarded) from public.revealed_answers where team = 'A'), 0),
      'B', coalesce((select sum(points_awarded) from public.revealed_answers where team = 'B'), 0)
    ),
    'revealedAnswerIds', coalesce((
      select jsonb_agg(r.answer_id order by r.answer_position)
      from public.revealed_answers r
      where r.question_id = g.active_question_id
    ), '[]'::jsonb)
  )
  from public.game_state g
  where g.singleton;
$$;

create function public.consume_host_pin_attempt(p_key_hash text)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_attempt public.host_login_attempts%rowtype;
begin
  if p_key_hash is null or p_key_hash !~ '^[a-f0-9]{64}$' then
    raise exception using message = 'INVALID_RATE_LIMIT_KEY';
  end if;

  insert into public.host_login_attempts(key_hash)
  values (p_key_hash)
  on conflict do nothing;

  select * into v_attempt
  from public.host_login_attempts
  where key_hash = p_key_hash
  for update;

  if v_attempt.blocked_until > clock_timestamp() then
    return false;
  end if;

  if v_attempt.window_started_at < clock_timestamp() - interval '15 minutes' then
    update public.host_login_attempts
    set attempts = 1, window_started_at = clock_timestamp(), blocked_until = null
    where key_hash = p_key_hash;
    return true;
  end if;

  if v_attempt.attempts >= 5 then
    update public.host_login_attempts
    set blocked_until = clock_timestamp() + interval '15 minutes'
    where key_hash = p_key_hash;
    return false;
  end if;

  update public.host_login_attempts
  set attempts = attempts + 1
  where key_hash = p_key_hash;
  return true;
end;
$$;

create function public.clear_host_pin_attempts(p_key_hash text)
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.host_login_attempts where key_hash = p_key_hash;
$$;

create function public.acquire_host_lease(p_token_hash text, p_takeover boolean)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_lease public.host_lease%rowtype;
  v_now timestamptz := clock_timestamp();
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
  values (true, p_token_hash, v_now + interval '60 seconds')
  on conflict (singleton) do update
  set token_hash = excluded.token_hash,
      expires_at = excluded.expires_at;

  return jsonb_build_object(
    'ok', true,
    'expiresAt', v_now + interval '60 seconds'
  );
end;
$$;

create function public.host_session_is_active(p_token_hash text)
returns boolean
language sql
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.host_sessions s
    join public.host_lease l on l.token_hash = s.token_hash
    where s.token_hash = p_token_hash
      and s.expires_at > clock_timestamp()
      and l.expires_at > clock_timestamp()
  );
$$;

create function public.heartbeat_host_lease(p_token_hash text)
returns timestamptz
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_expires_at timestamptz;
begin
  perform 1 from public.game_state where singleton for update;
  if not found then
    raise exception using message = 'GAME_NOT_INITIALIZED';
  end if;

  perform 1
  from public.host_lease l
  join public.host_sessions s on s.token_hash = l.token_hash
  where l.singleton
    and l.token_hash = p_token_hash
    and l.expires_at > clock_timestamp()
    and s.expires_at > clock_timestamp()
  for update of l;

  if not found then
    raise exception using message = 'HOST_LEASE_EXPIRED';
  end if;

  update public.host_lease
  set expires_at = clock_timestamp() + interval '60 seconds'
  where singleton
  returning expires_at into v_expires_at;

  return v_expires_at;
end;
$$;

create function public.release_host_lease(p_token_hash text)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform 1 from public.game_state where singleton for update;
  if not found then
    return;
  end if;

  update public.host_sessions
  set expires_at = clock_timestamp()
  where token_hash = p_token_hash;

  delete from public.host_lease
  where singleton and token_hash = p_token_hash;
end;
$$;

create function public.apply_game_action(
  p_token_hash text,
  p_request_id uuid,
  p_expected_version bigint,
  p_action text,
  p_question_id text default null,
  p_answer_id text default null,
  p_team text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_state public.game_state%rowtype;
  v_saved_payload jsonb;
  v_payload jsonb;
  v_answer public.answers%rowtype;
  v_game_action public.game_actions%rowtype;
  v_next_question_id text;
  v_question_count integer;
  v_min_position integer;
  v_max_position integer;
begin
  select * into v_state
  from public.game_state
  where singleton
  for update;

  if not found then
    raise exception using message = 'GAME_NOT_INITIALIZED';
  end if;

  perform 1
  from public.host_lease l
  join public.host_sessions s on s.token_hash = l.token_hash
  where l.singleton
    and l.token_hash = p_token_hash
    and l.expires_at > clock_timestamp()
    and s.expires_at > clock_timestamp()
  for update of l;

  if not found then
    raise exception using message = 'HOST_LEASE_EXPIRED';
  end if;

  if p_request_id is null or p_expected_version is null or p_action is null then
    raise exception using message = 'INVALID_COMMAND';
  end if;

  v_payload := jsonb_build_object(
    'action', p_action,
    'expectedVersion', p_expected_version,
    'questionId', p_question_id,
    'answerId', p_answer_id,
    'team', p_team
  );

  select request_payload into v_saved_payload
  from public.game_requests
  where request_id = p_request_id;

  if found then
    if v_saved_payload <> v_payload then
      raise exception using message = 'REQUEST_ID_REUSED';
    end if;
    return jsonb_build_object('ok', true, 'replayed', true, 'state', public.game_snapshot());
  end if;

  if p_expected_version <> v_state.version then
    raise exception using message = 'STALE_STATE';
  end if;

  if p_action not in (
    'start_game', 'open_answer', 'undo', 'redo', 'next_question',
    'finish_game', 'reset_question', 'reset_game'
  ) then
    raise exception using message = 'INVALID_ACTION';
  end if;

  if p_action = 'start_game' then
    if v_state.status <> 'READY' then
      raise exception using message = 'INVALID_GAME_STATUS';
    end if;

    select count(*), min(position), max(position)
    into v_question_count, v_min_position, v_max_position
    from public.questions;

    if v_question_count <> 3 or v_min_position <> 1 or v_max_position <> 3
      or exists (
        select 1 from public.questions q
        left join public.answers a on a.question_id = q.id
        group by q.id, q.title, q.content_verified
        having btrim(q.title) = '' or not q.content_verified
          or count(a.id) <> 5
          or count(a.id) filter (where btrim(a.answer_text) = '') > 0
      ) then
      raise exception using message = 'CONTENT_NOT_READY';
    end if;

    select id into v_next_question_id
    from public.questions where position = 1;
    update public.game_state
    set status = 'IN_PROGRESS', active_question_id = v_next_question_id
    where singleton;

  elsif p_action = 'open_answer' then
    if v_state.status <> 'IN_PROGRESS'
      or p_question_id is distinct from v_state.active_question_id
      or p_team not in ('A', 'B') or p_team is null
      or p_answer_id is null then
      raise exception using message = 'INVALID_COMMAND';
    end if;

    select * into v_answer
    from public.answers
    where id = p_answer_id and question_id = p_question_id;
    if not found then
      raise exception using message = 'ANSWER_NOT_FOUND';
    end if;

    if exists (
      select 1 from public.revealed_answers
      where question_id = p_question_id and answer_id = p_answer_id
    ) then
      raise exception using message = 'ANSWER_ALREADY_OPEN';
    end if;

    update public.game_actions
    set status = 'discarded', undo_order = null
    where question_id = p_question_id and status = 'undone';

    insert into public.game_actions(
      action_id, question_id, answer_id, answer_position, answer_text, points_awarded, team
    )
    values (
      p_request_id, p_question_id, p_answer_id, v_answer.position,
      v_answer.answer_text, v_answer.points, p_team
    );

    insert into public.revealed_answers(
      question_id, answer_id, answer_position, answer_text, points_awarded, team, action_id
    )
    values (
      p_question_id, p_answer_id, v_answer.position,
      v_answer.answer_text, v_answer.points, p_team, p_request_id
    );

  elsif p_action = 'undo' then
    if v_state.status <> 'IN_PROGRESS' then
      raise exception using message = 'INVALID_GAME_STATUS';
    end if;
    select * into v_game_action
    from public.game_actions
    where question_id = v_state.active_question_id and status = 'applied'
    order by action_order desc
    limit 1
    for update;
    if not found then
      raise exception using message = 'UNDO_EMPTY';
    end if;
    delete from public.revealed_answers where action_id = v_game_action.action_id;
    if not found then
      raise exception using message = 'UNDO_STATE_MISMATCH';
    end if;
    update public.game_actions
    set status = 'undone', undo_order = nextval('public.game_action_order_seq')
    where action_id = v_game_action.action_id;

  elsif p_action = 'redo' then
    if v_state.status <> 'IN_PROGRESS' then
      raise exception using message = 'INVALID_GAME_STATUS';
    end if;
    select * into v_game_action
    from public.game_actions
    where question_id = v_state.active_question_id and status = 'undone'
    order by undo_order desc
    limit 1
    for update;
    if not found then
      raise exception using message = 'REDO_EMPTY';
    end if;
    insert into public.revealed_answers(
      question_id, answer_id, answer_position, answer_text, points_awarded, team, action_id
    )
    values (
      v_game_action.question_id, v_game_action.answer_id,
      v_game_action.answer_position, v_game_action.answer_text,
      v_game_action.points_awarded, v_game_action.team, v_game_action.action_id
    );
    update public.game_actions
    set status = 'applied', undo_order = null
    where action_id = v_game_action.action_id;

  elsif p_action = 'next_question' then
    if v_state.status <> 'IN_PROGRESS' then
      raise exception using message = 'INVALID_GAME_STATUS';
    end if;

    select next_q.id into v_next_question_id
    from public.questions current_q
    join public.questions next_q on next_q.position = current_q.position + 1
    where current_q.id = v_state.active_question_id;
    if not found then
      raise exception using message = 'NO_NEXT_QUESTION';
    end if;

    update public.game_actions
    set status = 'discarded', undo_order = null
    where question_id = v_state.active_question_id
      and status in ('applied', 'undone');

    update public.game_state
    set active_question_id = v_next_question_id
    where singleton;

  elsif p_action = 'finish_game' then
    if v_state.status <> 'IN_PROGRESS' or not exists (
      select 1 from public.questions
      where id = v_state.active_question_id and position = 3
    ) then
      raise exception using message = 'INVALID_GAME_STATUS';
    end if;
    update public.game_state set status = 'COMPLETED' where singleton;

  elsif p_action = 'reset_question' then
    if v_state.status <> 'IN_PROGRESS' then
      raise exception using message = 'INVALID_GAME_STATUS';
    end if;
    delete from public.revealed_answers
    where question_id = v_state.active_question_id;
    update public.game_actions
    set status = 'discarded', undo_order = null
    where question_id = v_state.active_question_id;

  elsif p_action = 'reset_game' then
    delete from public.revealed_answers;
    delete from public.game_actions;
    update public.game_state
    set status = 'READY',
        active_question_id = (select id from public.questions where position = 1)
    where singleton;
  end if;

  update public.game_state
  set version = version + 1, updated_at = clock_timestamp()
  where singleton;

  insert into public.game_requests(request_id, request_payload)
  values (p_request_id, v_payload);

  return jsonb_build_object('ok', true, 'replayed', false, 'state', public.game_snapshot());
end;
$$;

revoke execute on function public.game_snapshot() from public, anon, authenticated;
revoke execute on function public.consume_host_pin_attempt(text) from public, anon, authenticated;
revoke execute on function public.clear_host_pin_attempts(text) from public, anon, authenticated;
revoke execute on function public.acquire_host_lease(text, boolean) from public, anon, authenticated;
revoke execute on function public.host_session_is_active(text) from public, anon, authenticated;
revoke execute on function public.heartbeat_host_lease(text) from public, anon, authenticated;
revoke execute on function public.release_host_lease(text) from public, anon, authenticated;
revoke execute on function public.apply_game_action(text, uuid, bigint, text, text, text, text) from public, anon, authenticated;

grant execute on function public.game_snapshot() to service_role;
grant execute on function public.consume_host_pin_attempt(text) to service_role;
grant execute on function public.clear_host_pin_attempts(text) to service_role;
grant execute on function public.acquire_host_lease(text, boolean) to service_role;
grant execute on function public.host_session_is_active(text) to service_role;
grant execute on function public.heartbeat_host_lease(text) to service_role;
grant execute on function public.release_host_lease(text) to service_role;
grant execute on function public.apply_game_action(text, uuid, bigint, text, text, text, text) to service_role;

do $$
begin
  if exists (select 1 from pg_catalog.pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_state'
    ) then
      execute 'alter publication supabase_realtime add table public.game_state';
    end if;
    if not exists (
      select 1 from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'revealed_answers'
    ) then
      execute 'alter publication supabase_realtime add table public.revealed_answers';
    end if;
  end if;
end;
$$;
