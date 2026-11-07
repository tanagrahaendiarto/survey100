begin;

create extension if not exists pgtap with schema extensions;
select plan(27);

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
insert into public.answers(id, question_id, position, answer_text)
select
  q.id || '-a' || a.position::text,
  q.id,
  a.position,
  'Test answer ' || q.id || '-' || a.position::text
from public.questions q
cross join (values (1), (2), (3), (4), (5)) as a(position)
where q.id in ('q3', 'q4', 'q5', 'q6');

select is((select count(*)::integer from public.questions), 7, 'seven contiguous questions are accepted');
select is((select count(*)::integer from public.answers), 35, 'each question has five answers');
select is((select position::integer from public.questions where id = 'q1'), 1, 'old question one stays first');
select is((select position::integer from public.questions where id = 'q4'), 2, 'old question four moves second');
select is((select position::integer from public.questions where id = 'q2'), 3, 'old question two moves third');
select is((select position::integer from public.questions where id = 'q5'), 4, 'old question five moves fourth');
select is((select position::integer from public.questions where id = 'q3'), 5, 'old question three moves fifth');
select is((select position::integer from public.questions where id = 'q6'), 6, 'old question six stays sixth');
select is((select position::integer from public.questions where id = 'q7'), 7, 'old question seven stays seventh');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000031', 0,
    'start_game', null, null
  )$$,
  'complete content starts a seven-question game'
);
select is(public.game_snapshot() ->> 'status', 'IN_PROGRESS', 'game starts');
select is(public.game_snapshot() ->> 'activeQuestionId', 'q1', 'question one starts active');
select is((public.game_snapshot() ->> 'questionCount')::integer, 7, 'snapshot reports the configured question count');

select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000032', 1,
    'next_question', null, null
  )$$,
  'question one advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q4', 'second displayed question is old question four');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000033', 2,
    'next_question', null, null
  )$$,
  'question two advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q2', 'third displayed question is old question two');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000034', 3,
    'next_question', null, null
  )$$,
  'question three advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q5', 'fourth displayed question is old question five');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000035', 4,
    'next_question', null, null
  )$$,
  'question four advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q3', 'fifth displayed question is old question three');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000036', 5,
    'next_question', null, null
  )$$,
  'question five advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q6', 'sixth displayed question is old question six');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000037', 6,
    'next_question', null, null
  )$$,
  'question six advances'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q7', 'question seven becomes active');
select lives_ok(
  $$select public.apply_game_action(
    repeat('b', 64), '00000000-0000-4000-8000-000000000038', 7,
    'finish_game', null, null
  )$$,
  'game can finish on its seventh configured question'
);
select is(public.game_snapshot() ->> 'status', 'COMPLETED', 'game finishes after question seven');

select * from finish();
rollback;
