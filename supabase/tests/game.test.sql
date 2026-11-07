begin;

create extension if not exists pgtap with schema extensions;
select plan(22);

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
update public.questions set content_verified = false where id = 'q6';

select throws_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000001', 0,
    'start_game', null, null, null
  )$$,
  'P0001', 'CONTENT_NOT_READY', 'game stays blocked until survey content is verified'
);

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
cross join (values (1, 50), (2, 30), (3, 20), (4, 15), (5, 5)) as a(position, points)
where q.position between 3 and 6;

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000002', 0,
    'start_game', null, null, null
  )$$,
  'valid content starts the game'
);
select is(public.game_snapshot() ->> 'status', 'IN_PROGRESS', 'first question starts');

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000003', 1,
    'open_answer', 'q1', 'q1-a1', 'A'
  )$$,
  'answer reveal and point award succeed together'
);
select is((public.game_snapshot() -> 'scores' ->> 'A')::integer, 50, 'team A receives the answer points');
update public.answers set answer_text = 'Changed later', points = 99 where id = 'q1-a1';
select is((select points_awarded from public.revealed_answers where answer_id = 'q1-a1'), 50, 'opened points are snapshotted');

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000003', 1,
    'open_answer', 'q1', 'q1-a1', 'A'
  )$$,
  'retrying the same request is idempotent'
);
select is((public.game_snapshot() -> 'scores' ->> 'A')::integer, 50, 'retry does not award points twice');

select throws_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000004', 2,
    'open_answer', 'q1', 'q1-a1', 'B'
  )$$,
  'P0001', 'ANSWER_ALREADY_OPEN', 'an opened answer cannot score twice'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000005', 2,
    'undo', null, null, null
  )$$,
  'undo closes the answer'
);
select is((public.game_snapshot() -> 'scores' ->> 'A')::integer, 0, 'undo restores the score');

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000006', 3,
    'redo', null, null, null
  )$$,
  'redo reopens the answer'
);
select is((public.game_snapshot() -> 'scores' ->> 'A')::integer, 50, 'redo restores the score');
select is((select answer_text from public.revealed_answers where answer_id = 'q1-a1'), 'Bangun kesiangan', 'redo restores the answer snapshot');

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000007', 4,
    'next_question', null, null, null
  )$$,
  'manual next question succeeds'
);
select is(public.game_snapshot() ->> 'activeQuestionId', 'q2', 'next question becomes active');
select throws_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000008', 5,
    'undo', null, null, null
  )$$,
  'P0001', 'UNDO_EMPTY', 'undo history does not cross questions'
);

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000009', 5,
    'reset_question', null, null, null
  )$$,
  'reset question succeeds'
);
select is((public.game_snapshot() -> 'scores' ->> 'A')::integer, 50, 'reset question keeps earlier question score');

select lives_ok(
  $$select public.apply_game_action(
    repeat('a', 64), '00000000-0000-4000-8000-000000000010', 6,
    'reset_game', null, null, null
  )$$,
  'reset game succeeds'
);
select is((public.game_snapshot() -> 'scores' ->> 'A')::integer, 0, 'reset game clears all scores');
select is(public.game_snapshot() ->> 'status', 'READY', 'reset game requires starting again');

select * from finish();
rollback;
