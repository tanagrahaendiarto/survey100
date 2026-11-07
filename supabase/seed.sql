-- Local development demo content only.
-- These synthetic points are not survey results and must not be used for the event or pushed to Cloud.
begin;

update public.questions
set title = case id
      when 'q1' then 'DEMO — Apa alasan paling umum mahasiswa datang terlambat ke kelas?'
      when 'q2' then 'DEMO — Apa alasan mahasiswa memilih duduk di bagian belakang kelas?'
      when 'q3' then 'DEMO — Apa kegiatan yang paling sering dilakukan mahasiswa saat jeda kuliah?'
      when 'q4' then 'DEMO — Barang apa yang paling sering tertinggal saat berangkat kuliah?'
      when 'q5' then 'DEMO — Tempat favorit mahasiswa untuk mengerjakan tugas?'
      when 'q6' then 'DEMO — Minuman yang paling sering dibeli mahasiswa di kampus?'
    end,
    content_verified = true
where id in ('q1', 'q2', 'q3', 'q4', 'q5', 'q6');

insert into public.answers(id, question_id, position, answer_text, points)
values
  ('q3-a1', 'q3', 1, 'Ngobrol dengan teman', 50),
  ('q3-a2', 'q3', 2, 'Membuka media sosial', 30),
  ('q3-a3', 'q3', 3, 'Makan atau jajan', 20),
  ('q3-a4', 'q3', 4, 'Mengerjakan tugas', 15),
  ('q3-a5', 'q3', 5, 'Tidur sebentar', 5),
  ('q4-a1', 'q4', 1, 'Charger', 50),
  ('q4-a2', 'q4', 2, 'Kartu mahasiswa', 30),
  ('q4-a3', 'q4', 3, 'Botol minum', 20),
  ('q4-a4', 'q4', 4, 'Buku atau catatan', 15),
  ('q4-a5', 'q4', 5, 'Payung', 5),
  ('q5-a1', 'q5', 1, 'Kafe', 50),
  ('q5-a2', 'q5', 2, 'Kos', 30),
  ('q5-a3', 'q5', 3, 'Perpustakaan', 20),
  ('q5-a4', 'q5', 4, 'Ruang kelas', 15),
  ('q5-a5', 'q5', 5, 'Taman kampus', 5),
  ('q6-a1', 'q6', 1, 'Es kopi', 50),
  ('q6-a2', 'q6', 2, 'Air mineral', 30),
  ('q6-a3', 'q6', 3, 'Teh', 20),
  ('q6-a4', 'q6', 4, 'Minuman boba', 15),
  ('q6-a5', 'q6', 5, 'Jus', 5)
on conflict (id) do update
set question_id = excluded.question_id,
    position = excluded.position,
    answer_text = excluded.answer_text,
    points = excluded.points;

commit;
