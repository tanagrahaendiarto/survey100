-- Restore the least-privilege policy and function settings expected by the app.
-- The cloud project already has the base tables, but its migration history and
-- several security settings drifted from the checked-in migrations.

alter table public.revealed_answers enable row level security;

drop policy if exists display_active_question_only on public.revealed_answers;
create policy display_active_question_only on public.revealed_answers
  as restrictive
  for select
  to anon
  using (
    question_id = (
      select active_question_id
      from public.game_state
      where singleton
    )
  );

alter function public.game_snapshot() security invoker;
alter function public.consume_host_pin_attempt(text) security invoker;
alter function public.clear_host_pin_attempts(text) security invoker;
alter function public.acquire_host_lease(text, boolean) security invoker;
alter function public.host_session_is_active(text) security invoker;
alter function public.heartbeat_host_lease(text) security invoker;
alter function public.release_host_lease(text) security invoker;
alter function public.apply_game_action(text, uuid, bigint, text, text, text, text) security invoker;

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

revoke all on table
  public.questions, public.answers, public.game_state, public.game_actions,
  public.revealed_answers, public.game_requests, public.host_sessions,
  public.host_lease, public.host_login_attempts
  from public, anon, authenticated, service_role;

grant usage on schema public to anon, service_role;
grant select on table public.game_state, public.revealed_answers to anon;

grant select on table public.questions, public.answers to service_role;
grant select, update on table public.game_state to service_role;
grant select, insert, update, delete on table public.game_actions to service_role;
grant select, insert, delete on table public.revealed_answers to service_role;
grant select, insert on table public.game_requests to service_role;
grant select, insert, update on table public.host_sessions to service_role;
grant select, insert, update, delete on table public.host_lease to service_role;
grant select, insert, update, delete on table public.host_login_attempts to service_role;

revoke all on sequence public.game_action_order_seq from public, anon, authenticated, service_role;
grant usage on sequence public.game_action_order_seq to service_role;
