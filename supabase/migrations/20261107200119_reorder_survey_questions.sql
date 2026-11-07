-- Reorder existing survey questions without changing their text or answers.
do $$
declare
  v_status text;
  v_active_question_id text;
  v_active_position integer;
  v_new_position integer;
begin
  select status, active_question_id
  into v_status, v_active_question_id
  from public.game_state
  where singleton
  for update;

  if not found then
    raise exception using message = 'GAME_NOT_INITIALIZED';
  end if;

  select position into v_active_position
  from public.questions
  where id = v_active_question_id;

  v_new_position := case v_active_question_id
    when 'q1' then 1
    when 'q4' then 2
    when 'q2' then 3
    when 'q5' then 4
    when 'q3' then 5
    when 'q6' then 6
    when 'q7' then 7
  end;

  if v_status = 'IN_PROGRESS'
    and (
      v_active_position is distinct from v_new_position
      or exists (select 1 from public.revealed_answers)
      or exists (select 1 from public.game_actions)
    ) then
    raise exception using message = 'GAME_MUST_BE_QUIET_TO_REORDER';
  end if;

  if (select count(*) from public.questions) <> 7
    or exists (
      select 1
      from (values
        ('q1', 1), ('q2', 2), ('q3', 3), ('q4', 4),
        ('q5', 5), ('q6', 6), ('q7', 7)
      ) as expected(id, position)
      left join public.questions q on q.id = expected.id
      where q.id is null or q.position <> expected.position
    ) then
    raise exception using message = 'UNEXPECTED_QUESTION_ORDER';
  end if;
end;
$$;

-- Move positions out of the unique 1..7 range before assigning the new order.
update public.questions
set position = position + 100
where id in ('q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7');

update public.questions
set position = case id
  when 'q1' then 1
  when 'q4' then 2
  when 'q2' then 3
  when 'q5' then 4
  when 'q3' then 5
  when 'q6' then 6
  when 'q7' then 7
end
where id in ('q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7');

-- Notify active Host and Display clients to reload the newly ordered questions.
update public.game_state
set version = version + 1,
    updated_at = clock_timestamp()
where singleton;
