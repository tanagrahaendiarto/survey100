begin;

create extension if not exists pgtap with schema extensions;
select plan(20);

delete from public.host_lease where singleton;
delete from public.host_sessions where token_hash = repeat('b', 64);

insert into public.host_sessions(token_hash, expires_at)
values (repeat('b', 64), now() + interval '1 hour');
insert into public.host_lease(singleton, token_hash, expires_at)
values (true, repeat('b', 64), now() + interval '1 minute');
delete from public.revealed_answers;
delete from public.game_actions;
delete from public.game_requests;
update public.game_state
set status = 'READY', active_question_id = 'q1', version = 0, updated_at = now()
where singleton;

update public.questions
set title = case
      when position >= 3 then 'Test question ' || position::text
      else title
    end,
    content_verified = true;
delete from public.answers where question_id in ('q3', 'q4', 'q5', 'q6');
insert into public.answers(id, question_id, position, answer_text, points)
select
  'q' || q.position::text || '-a' || a.position::text,
  q.id,
  a.position,
  'Test answer ' || q.position::text || '-' || a.position::text,
  a.points
from public.questions q
cross join (values (1, 50), (2, 40), (3, 30), (4, 20), (5, 10)) as a(position, points)
where q.position between 3 and 6;

select is((select count(*)::integer from public.questions), 7, 'seven contiguous questions are accepted');
select is((select count(*)::integer from public.answers), 35, 'each question has five answers');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000031', 0,
    'start_game', null, null, null
  )$$,
  'complete content starts a seven-question game'
);
select is(public.game_snapshot() ->> 'status', 'IN_PROGRESS', 'game starts');
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'question one starts active');
select is((public.game_snapshot() ->> 'questionCount')::integer, 7, 'snapshot reports the configured question count');

select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000032', 1,
    'next_question', null, null, null
  )$$,
  'question one advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q2', 'question two becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000033', 2,
    'next_question', null, null, null
  )$$,
  'question two advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q3', 'question three becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000034', 3,
    'next_question', null, null, null
  )$$,
  'question three advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q4', 'question four becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000035', 4,
    'next_question', null, null, null
  )$$,
  'question four advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q5', 'question five becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000036', 5,
    'next_question', null, null, null
  )$$,
  'question five advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q6', 'question six becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000037', 6,
    'next_question', null, null, null
  )$$,
  'question six advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q7', 'question seven becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000038', 7,
    'finish_game', null, null, null
  )$$,
  'game can finish on its seventh configured question'
);
select is(public.game_snapshot() ->> 'status', 'COMPLETED', 'game finishes after question seven');

select * from finish();
rollback;
