# Supabase setup

1. Keep Cloud credentials in `.env.local`. For local Next.js development, use the ignored `.env.development.local`; Next.js loads it before `.env.local`, so the local API can be used without replacing Cloud settings.
2. Review and apply `migrations/20261106000100_game.sql` only after approving the final migration. It limits Display reads to the active question and grants only the access each role needs.
3. Add each question in order, with exactly five answers and verified survey points. Positions must be contiguous starting at 1. Set `content_verified = true` only after the question and all points are verified.
4. Restart Next.js after changing `.env.local`.

Get `SUPABASE_SECRET_KEY` from the same project's **Project Settings → API Keys**. If direct database access is blocked by IPv6, get the Session Pooler connection URI from **Connect** and store it as `SUPABASE_DB_URL`; do not send either credential over chat.

Confirm `public` is listed under the project's Data API exposed schemas. The migration grants only the tables needed by the browser and keeps questions/answers server-only.

With Supabase CLI and Docker running, validate the database logic with `supabase start` followed by `supabase test db`. Do not run a hosted `db push` until the migration set is approved.

The migrations configure six questions (Q1–Q6). The base migration provides Q1/Q2 examples and Q3; the next migration adds Q4–Q6. `seed.sql` supplies six fictional demo questions with five answers each (30 answers total) and marks them ready so the full game can be tried locally. They are demo content, not survey results, and must not be used for the event or pushed to Cloud. The seed is applied to the local stack only. The game supports a variable number of questions, each with exactly five answers. Replace demo content with verified event content before the event. Never expose `SUPABASE_SECRET_KEY` as a `NEXT_PUBLIC_` variable.
