alter table public.questions
  drop constraint if exists questions_position_check;

alter table public.questions
  add constraint questions_position_check check (position >= 1);

insert into public.questions(id, position, title, content_verified)
values
  ('q4', 4, '', false),
  ('q5', 5, '', false),
  ('q6', 6, '', false);

create or replace function public.game_snapshot()
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'status', g.status,
    'activeQuestionId', g.active_question_id,
    'questionCount', (select count(*)::integer from public.questions),
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

create or replace function public.apply_game_action(
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

    if v_question_count = 0 or v_min_position <> 1 or v_max_position <> v_question_count
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
      select 1 from public.questions q
      where q.id = v_state.active_question_id
        and q.position = (select max(position) from public.questions)
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
