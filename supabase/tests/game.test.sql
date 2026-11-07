begin;

create extension if not exists pgtap with schema extensions;
select plan(43);

delete from public.host_lease where singleton;
delete from public.host_sessions where token_hash = repeat('a', 64);

insert into public.host_sessions(token_hash, expires_at)
values (repeat('a', 64), now() + interval '1 hour');
insert into public.host_lease(singleton, token_hash, expires_at)
values (true, repeat('a', 64), now() + interval '1 minute');
delete from public.revealed_answers;
delete from public.game_actions;
delete from public.game_requests;
update public.game_state
set status = 'READY', active_question_id = 'q1', version = 0, updated_at = now()
where singleton;
update public.questions
set title = 'Test question ' || position::text,
    content_verified = true;
delete from public.answers;
insert into public.answers(id, question_id, position, answer_text)
select
  q.id || '-test-a' || a.position::text,
  q.id,
  a.position,
  'Test answer ' || q.position::text || '-' || a.position::text
from public.questions q
cross join (values (1), (2), (3), (4), (5)) as a(position);
update public.questions set content_verified = false where id = 'q6';

select throws_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000001', 0,
    'start_game', null, null
  )$$,
  'P0001', 'CONTENT_NOT_READY', 'game stays blocked until survey content is verified'
);

update public.questions set content_verified = true where id = 'q6';

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000002', 0,
    'start_game', null, null
  )$$,
  'valid content starts the game'
);
select is(public.game_snapshot() ->> 'status', 'IN_PROGRESS', 'first question starts');
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'question one starts active');
select is(public.game_snapshot() ? 'scores', false, 'game snapshot does not contain scores');
select is(
  (select count(*)::integer from information_schema.columns
   where table_schema = 'public' and table_name = 'answers' and column_name = 'points'),
  0,
  'answer points are no longer stored'
);
select is(
  (select count(*)::integer from information_schema.columns
   where table_schema = 'public' and table_name = 'game_actions' and column_name in ('points_awarded', 'team')),
  0,
  'action history has no score or team fields'
);
select is(
  (select count(*)::integer from information_schema.columns
   where table_schema = 'public' and table_name = 'revealed_answers' and column_name in ('points_awarded', 'team')),
  0,
  'revealed answers have no score or team fields'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000003', 1,
    'open_answer', 'q1', 'q1-test-a1'
  )$$,
  'answer opens without team or point input'
);
select is(
  (select answer_text from public.revealed_answers where answer_id = 'q1-test-a1'),
  'Test answer 1-1',
  'opened answer text is shown'
);
update public.answers set answer_text = 'Changed later' where id = 'q1-test-a1';
select is(
  (select answer_text from public.revealed_answers where answer_id = 'q1-test-a1'),
  'Test answer 1-1',
  'opened answer text is snapshotted'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000003', 1,
    'open_answer', 'q1', 'q1-test-a1'
  )$$,
  'retrying the same request is idempotent'
);
select is(
  (select count(*)::integer from public.revealed_answers where question_id = 'q1'),
  1,
  'retry does not reveal the answer twice'
);

select throws_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000004', 2,
    'open_answer', 'q1', 'q1-test-a1'
  )$$,
  'P0001', 'ANSWER_ALREADY_OPEN', 'an opened answer cannot open twice'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000005', 2,
    'undo', null, null
  )$$,
  'undo closes the answer'
);
select is(
  (select count(*)::integer from public.revealed_answers where question_id = 'q1'),
  0,
  'undo closes the answer'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000006', 3,
    'redo', null, null
  )$$,
  'redo reopens the answer'
);
select is(
  (select answer_text from public.revealed_answers where answer_id = 'q1-test-a1'),
  'Test answer 1-1',
  'redo restores the answer snapshot'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000007', 4,
    'next_question', null, null
  )$$,
  'manual next question succeeds'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q2', 'next question becomes active');
select throws_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000008', 5,
    'undo', null, null
  )$$,
  'P0001', 'UNDO_EMPTY', 'undo history does not cross questions'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000009', 5,
    'reset_question', null, null
  )$$,
  'reset question succeeds'
);
select is(
  (select count(*)::integer from public.revealed_answers where question_id = 'q2'),
  0,
  'reset question closes its answers'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000010', 6,
    'restart_game', null, null
  )$$,
  'restart game succeeds'
);
select is(public.game_snapshot() ->> 'status', 'IN_PROGRESS', 'restart immediately starts the game');
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'restart returns to question one');
select is(
  (select count(*)::integer from public.revealed_answers),
  0,
  'restart closes all previously opened answers'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000011', 7,
    'open_answer', 'q1', 'q1-test-a1'
  )$$,
  'question one can be opened again after restart'
);
select is(
  (select count(*)::integer from public.revealed_answers where question_id = 'q1'),
  1,
  'question one answers are available again after restart'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000012', 8,
    'reset_game', null, null
  )$$,
  'reset to ready state succeeds'
);
select is(public.game_snapshot() ->> 'status', 'READY', 'reset returns game to ready state');
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'reset selects question one');
select is(
  (select count(*)::integer from public.revealed_answers),
  0,
  'reset closes all opened answers'
);
select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000013', 9,
    'start_game', null, null
  )$$,
  'game can start again after reset'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'starting again begins at question one');

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000014', 10,
    'open_answer', 'q1', 'q1-test-a1'
  )$$,
  'an answer can be opened before replaying a completed game'
);
update public.game_state
set status = 'COMPLETED', active_question_id = 'q7'
where singleton;
select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000015', 11,
    'restart_game', null, null
  )$$,
  'restart succeeds from the completed state'
);
select is(public.game_snapshot() ->> 'status', 'IN_PROGRESS', 'completed game restart starts immediately');
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'completed game restart selects question one');
select is(public.game_snapshot() ->> 'version', '12', 'completed game restart increments the version');
select is(
  (select count(*)::integer from public.revealed_answers),
  0,
  'completed game restart closes all previously opened answers'
);
select is(
  (select count(*)::integer from public.game_actions),
  0,
  'completed game restart clears the answer action history'
);
select is((public.game_snapshot() ? 'scores') or (public.game_snapshot() ? 'teams'), false,
  'completed game restart does not restore scores or teams');

select * from finish();
rollback;
