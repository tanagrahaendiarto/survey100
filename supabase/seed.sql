-- Local development test content only.
-- This seed is local-only; never include it when pushing migrations to Cloud.
begin;

delete from public.revealed_answers;
delete from public.game_actions;
delete from public.game_requests;
delete from public.answers;

update public.questions
set title = case id
      when 'q1' then 'Panggilan “kakak perempuan” yang sering digunakan di Indonesia'
      when 'q2' then 'Kenapa orang makan'
      when 'q3' then 'Kombinasi nasi putih+lauk aneh yang biasa dimakan sama anak kost'
      when 'q4' then 'Apa alasan paling umum mahasiswa datang terlambat ke kelas?'
      when 'q5' then 'Apa yang dilakukan mahasiswa ketika deadline tugas tinggal 1 jam?'
      when 'q6' then 'Sebutkan alasan mahasiswa memilih duduk di bagian belakang kelas!'
      when 'q7' then 'Apa hal yang paling sering membuat mahasiswa stres selama kuliah?'
    end,
    content_verified = true
where id in ('q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7');

update public.game_state
set status = 'READY', active_question_id = 'q1', version = 0, updated_at = now()
where singleton;

insert into public.answers(id, question_id, position, answer_text)
values
  ('q1-a1', 'q1', 1, 'ceuceu'),
  ('q1-a2', 'q1', 2, 'uni'),
  ('q1-a3', 'q1', 3, 'cici'),
  ('q1-a4', 'q1', 4, 'mpok'),
  ('q1-a5', 'q1', 5, 'mbak'),
  ('q2-a1', 'q2', 1, 'Lapar'),
  ('q2-a2', 'q2', 2, 'Gabut'),
  ('q2-a3', 'q2', 3, 'Karena ingin'),
  ('q2-a4', 'q2', 4, 'Bertahan hidup'),
  ('q2-a5', 'q2', 5, 'Lagi stress'),
  ('q3-a1', 'q3', 1, 'Nasi + nasi goreng'),
  ('q3-a2', 'q3', 2, 'Nasi + martabak telor'),
  ('q3-a3', 'q3', 3, 'Nasi + siomay'),
  ('q3-a4', 'q3', 4, 'Nasi + Citato'),
  ('q3-a5', 'q3', 5, 'Nasi + Mie goreng'),
  ('q4-a1', 'q4', 1, 'Bangun kesiangan'),
  ('q4-a2', 'q4', 2, 'Terjebak macet'),
  ('q4-a3', 'q4', 3, 'Nugas sampai begadang'),
  ('q4-a4', 'q4', 4, 'Menunggu teman'),
  ('q4-a5', 'q4', 5, 'Antre mandi'),
  ('q5-a1', 'q5', 1, 'Meminta bantuan ChatGPT'),
  ('q5-a2', 'q5', 2, 'Copy-paste pekerjaan teman'),
  ('q5-a3', 'q5', 3, 'Mengerjakan dan mengumpulkan seadanya'),
  ('q5-a4', 'q5', 4, 'Panik dan overthinking'),
  ('q5-a5', 'q5', 5, 'Meminta perpanjangan waktu'),
  ('q6-a1', 'q6', 1, 'Bisa tidur tanpa ketahuan'),
  ('q6-a2', 'q6', 2, 'Bisa bermain HP'),
  ('q6-a3', 'q6', 3, 'Tidak mau ditunjuk dosen'),
  ('q6-a4', 'q6', 4, 'Lebih bebas mengobrol'),
  ('q6-a5', 'q6', 5, 'Bisa keluar kelas dengan mudah'),
  ('q7-a1', 'q7', 1, 'Tugas menumpuk'),
  ('q7-a2', 'q7', 2, 'Deadline berdekatan'),
  ('q7-a3', 'q7', 3, 'Nilai ujian jelek'),
  ('q7-a4', 'q7', 4, 'Masalah keuangan'),
  ('q7-a5', 'q7', 5, 'Organisasi dan kepanitiaan');

commit;
