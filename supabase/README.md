# Supabase setup

1. Keep Cloud credentials in `.env.local`. For local Next.js development, use the ignored `.env.development.local`; Next.js loads it before `.env.local`, so the local API can be used without replacing Cloud settings.
2. Review and apply the migrations in order. They limit Display reads to the active question and grant only the access each role needs.
3. Each question must have five answers and contiguous positions starting at 1. Set `content_verified = true` only after organizer review. Answers are revealed without points or team assignment.
4. Restart Next.js after changing `.env.local`.

Get `SUPABASE_SECRET_KEY` from the same project's **Project Settings → API Keys**. For CLI access to a hosted database, use the Session Pooler connection URI from **Connect** as `SUPABASE_DB_URL` if direct access is blocked by IPv6; do not send either credential over chat.

Confirm `public` is listed under the project's Data API exposed schemas. The migration grants only the tables needed by the browser and keeps questions/answers server-only.

With Supabase CLI and Docker running, validate the database logic with `supabase start` followed by `supabase test db`. Do not run a hosted `db push` until the migration set is approved.

The local play-test setup has seven questions (Q1–Q7), each with five answers. `seed.sql` applies test content to the local stack only—never include seed data in a Cloud push. The app supports a variable number of questions, and the Host can restart directly from Question 1. Never expose `SUPABASE_SECRET_KEY` as a `NEXT_PUBLIC_` variable.
