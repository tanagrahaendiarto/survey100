begin;

create extension if not exists pgtap with schema extensions;
select plan(17);

delete from public.revealed_answers;
delete from public.game_actions;
delete from public.game_requests;
update public.game_state
set status = 'READY', active_question_id = 'q1', version = 0, updated_at = now()
where singleton;

insert into public.game_actions(
  action_id, question_id, answer_id, answer_position, answer_text
)
values
  ('00000000-0000-4000-8000-000000000021', 'q1', 'q1-a1', 1, 'Bangun kesiangan'),
  ('00000000-0000-4000-8000-000000000022', 'q2', 'q2-a1', 1, 'Bisa bermain HP');
insert into public.revealed_answers(
  question_id, answer_id, answer_position, answer_text, action_id
)
values
  ('q1', 'q1-a1', 1, 'Bangun kesiangan', '00000000-0000-4000-8000-000000000021'),
  ('q2', 'q2-a1', 1, 'Bisa bermain HP', '00000000-0000-4000-8000-000000000022');

select is(
  (select count(*)::integer
   from pg_catalog.pg_class c
   join pg_catalog.pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in (
       'questions', 'answers', 'game_state', 'game_actions', 'revealed_answers',
       'game_requests', 'host_sessions', 'host_lease', 'host_login_attempts'
     )
     and c.relrowsecurity),
  9,
  'RLS is enabled on every application table'
);

select ok(
  has_table_privilege('anon', 'public.game_state', 'select'),
  'Display can read the safe game state'
);
select ok(
  has_table_privilege('anon', 'public.revealed_answers', 'select'),
  'Display can read opened answers only'
);
select ok(
  not has_table_privilege('anon', 'public.questions', 'select')
  and not has_table_privilege('anon', 'public.answers', 'select')
  and not has_table_privilege('anon', 'public.game_actions', 'select')
  and not has_table_privilege('anon', 'public.game_requests', 'select')
  and not has_table_privilege('anon', 'public.host_sessions', 'select')
  and not has_table_privilege('anon', 'public.host_lease', 'select')
  and not has_table_privilege('anon', 'public.host_login_attempts', 'select'),
  'Display cannot read question configuration or Host internals'
);
select ok(
  not has_table_privilege('authenticated', 'public.questions', 'select')
  and not has_table_privilege('authenticated', 'public.answers', 'select')
  and not has_table_privilege('authenticated', 'public.game_state', 'select')
  and not has_table_privilege('authenticated', 'public.revealed_answers', 'select')
  and not has_table_privilege('authenticated', 'public.game_actions', 'select')
  and not has_table_privilege('authenticated', 'public.game_requests', 'select')
  and not has_table_privilege('authenticated', 'public.host_sessions', 'select')
  and not has_table_privilege('authenticated', 'public.host_lease', 'select')
  and not has_table_privilege('authenticated', 'public.host_login_attempts', 'select'),
  'Authenticated clients receive no direct table access'
);
select ok(
  not has_table_privilege('anon', 'public.game_state', 'insert')
  and not has_table_privilege('anon', 'public.game_state', 'update')
  and not has_table_privilege('anon', 'public.game_state', 'delete')
  and not has_table_privilege('anon', 'public.revealed_answers', 'insert')
  and not has_table_privilege('anon', 'public.revealed_answers', 'update')
  and not has_table_privilege('anon', 'public.revealed_answers', 'delete'),
  'Display cannot mutate game state'
);
select ok(
  not has_table_privilege('authenticated', 'public.game_state', 'insert')
  and not has_table_privilege('authenticated', 'public.game_state', 'update')
  and not has_table_privilege('authenticated', 'public.game_state', 'delete'),
  'Authenticated clients cannot mutate game state'
);

select ok(
  not has_function_privilege('anon', 'public.game_snapshot()', 'execute'),
  'Anonymous clients cannot call internal snapshot RPC'
);
select ok(
  not has_function_privilege('anon', 'public.apply_game_action(text,uuid,bigint,text,text,text)', 'execute')
  and not has_function_privilege('authenticated', 'public.apply_game_action(text,uuid,bigint,text,text,text)', 'execute'),
  'Client roles cannot call the mutation RPC'
);
select ok(
  has_function_privilege('service_role', 'public.apply_game_action(text,uuid,bigint,text,text,text)', 'execute'),
  'Only the server role can call the mutation RPC'
);
select ok(
  has_table_privilege('service_role', 'public.questions', 'select')
  and has_table_privilege('service_role', 'public.answers', 'select')
  and has_table_privilege('service_role', 'public.game_state', 'update'),
  'Server role has the minimum configuration and state access'
);
select is(
  (select count(*)::integer
   from pg_catalog.pg_proc p
   join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in (
       'game_snapshot', 'consume_host_pin_attempt', 'clear_host_pin_attempts',
       'acquire_host_lease', 'host_session_is_active', 'heartbeat_host_lease',
       'release_host_lease', 'apply_game_action'
     )
     and not p.prosecdef),
  8,
  'Internal RPCs run as invokers, not as the migration owner'
);
select ok(
  exists (select 1 from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'game_state' and policyname = 'display_reads_game_state' and roles = array['anon']::name[])
  and exists (select 1 from pg_catalog.pg_policies where schemaname = 'public' and tablename = 'revealed_answers' and policyname = 'display_reads_revealed_answers' and roles = array['anon']::name[]),
  'Public read policies are limited to anon and safe display tables'
);
select ok(
  exists (select 1 from pg_catalog.pg_policies where schemaname = 'realtime' and tablename = 'messages' and policyname = 'display_receives_game_events' and roles = array['anon']::name[]),
  'Display can receive only the public game soundboard topic'
);

set local role anon;
select results_eq(
  $$select question_id from public.revealed_answers order by question_id$$,
  array['q1']::text[],
  'Display cannot read opened answers from a non-active question'
);
select throws_ok(
  $$select answer_text from public.answers$$,
  '42501', null,
  'Display cannot read hidden answer configuration'
);
reset role;
update public.game_state set active_question_id = 'q2' where singleton;
set local role anon;
select results_eq(
  $$select question_id from public.revealed_answers order by question_id$$,
  array['q2']::text[],
  'Display access follows the active question after a transition'
);
reset role;

select * from finish();
rollback;
