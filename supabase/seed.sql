-- Local development test content only.
-- This seed is local-only; never include it when pushing migrations to Cloud.
begin;

delete from public.revealed_answers where question_id is not null;
delete from public.game_actions where question_id is not null;
delete from public.game_requests where request_id is not null;
delete from public.answers where question_id is not null;
-- game_state.active_question_id references questions, so re-create the row below.
delete from public.game_state where singleton;
delete from public.questions where id is not null;

insert into public.questions(id, position, title, content_verified)
values
  ('q1', 1, 'Apa alasan mahasiswa datang terlambat ke kampus?', true),
  ('q2', 2, 'Apa yang biasanya dilakukan mahasiswa ketika dosen tidak masuk?', true),
  ('q3', 3, 'Sebutkan benda yang wajib dibawa mahasiswa ke kampus!', true),
  ('q4', 4, 'Apa yang membuat mahasiswa stres?', true),
  ('q5', 5, 'Apa yang biasanya dilakukan mahasiswa ketika mendapat tugas kelompok?', true),
  ('q6', 6, 'Apa alasan mahasiswa duduk di bangku paling belakang?', true);

insert into public.game_state(singleton, status, active_question_id, version, updated_at)
values (true, 'READY', 'q1', 0, now());

insert into public.answers(id, question_id, position, answer_text)
values
  ('q1-a1', 'q1', 1, 'Bangun kesiangan'),
  ('q1-a2', 'q1', 2, 'Macet'),
  ('q1-a3', 'q1', 3, 'Jarak rumah jauh'),
  ('q1-a4', 'q1', 4, 'Menunggu kendaraan'),
  ('q1-a5', 'q1', 5, 'Begadang'),
  ('q2-a1', 'q2', 1, 'Pulang'),
  ('q2-a2', 'q2', 2, 'Tidur'),
  ('q2-a3', 'q2', 3, 'Main HP'),
  ('q2-a4', 'q2', 4, 'Nongkrong'),
  ('q2-a5', 'q2', 5, 'Mengerjakan tugas'),
  ('q3-a1', 'q3', 1, 'HP'),
  ('q3-a2', 'q3', 2, 'Dompet'),
  ('q3-a3', 'q3', 3, 'Laptop'),
  ('q3-a4', 'q3', 4, 'Buku'),
  ('q3-a5', 'q3', 5, 'Alat tulis'),
  ('q4-a1', 'q4', 1, 'Tugas menumpuk'),
  ('q4-a2', 'q4', 2, 'Deadline'),
  ('q4-a3', 'q4', 3, 'Masalah keuangan'),
  ('q4-a4', 'q4', 4, 'Dosen killer'),
  ('q4-a5', 'q4', 5, 'Masalah percintaan'),
  ('q5-a1', 'q5', 1, 'Membuat grup WhatsApp'),
  ('q5-a2', 'q5', 2, 'Membagi tugas'),
  ('q5-a3', 'q5', 3, 'Menentukan ketua'),
  ('q5-a4', 'q5', 4, 'Mencari referensi'),
  ('q5-a5', 'q5', 5, 'Bingung menentukan jadwal'),
  ('q6-a1', 'q6', 1, 'Bisa santai'),
  ('q6-a2', 'q6', 2, 'Tidak terlalu diperhatikan dosen'),
  ('q6-a3', 'q6', 3, 'Bisa bermain HP'),
  ('q6-a4', 'q6', 4, 'Terbiasa duduk belakang'),
  ('q6-a5', 'q6', 5, 'Datang terlambat');

commit;
