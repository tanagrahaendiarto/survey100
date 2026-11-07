-- Organizer-provided questions for the initial online play test.
-- Points use temporary rank weights (50, 40, 30, 20, 10), not survey counts.
begin;

do $$
declare
  v_status text;
begin
  select status into v_status
  from public.game_state
  where singleton
  for update;

  if not found or v_status <> 'READY' then
    raise exception using message = 'GAME_MUST_BE_READY_TO_REPLACE_CONTENT';
  end if;

  if exists (select 1 from public.game_actions)
    or exists (select 1 from public.revealed_answers)
    or exists (
      select 1 from public.host_lease
      where singleton and expires_at > clock_timestamp()
    ) then
    raise exception using message = 'GAME_ACTIVITY_EXISTS_CONTENT_NOT_REPLACED';
  end if;

  if (select count(*) from public.questions where id in ('q1','q2','q3','q4','q5','q6')) <> 6 then
    raise exception using message = 'EXPECTED_SIX_EXISTING_QUESTIONS';
  end if;
end;
$$;

update public.questions
set title = case id
  when 'q1' then 'Panggilan “kakak perempuan” yang sering digunakan di Indonesia'
  when 'q2' then 'Kenapa orang makan'
  when 'q3' then 'Kombinasi nasi putih+lauk aneh yang biasa dimakan sama anak kost'
  when 'q4' then 'Apa alasan paling umum mahasiswa datang terlambat ke kelas?'
  when 'q5' then 'Apa yang dilakukan mahasiswa ketika deadline tugas tinggal 1 jam?'
  when 'q6' then 'Sebutkan alasan mahasiswa memilih duduk di bagian belakang kelas!'
end,
    content_verified = true
where id in ('q1','q2','q3','q4','q5','q6');

insert into public.questions(id, position, title, content_verified)
values ('q7', 7, 'Apa hal yang paling sering membuat mahasiswa stres selama kuliah?', true)
on conflict (id) do update
set position = excluded.position,
    title = excluded.title,
    content_verified = excluded.content_verified;

delete from public.answers
where question_id in ('q1','q2','q3','q4','q5','q6','q7');

insert into public.answers(id, question_id, position, answer_text, points)
values
  ('q1-a1', 'q1', 1, 'ceuceu', 50),
  ('q1-a2', 'q1', 2, 'uni', 40),
  ('q1-a3', 'q1', 3, 'cici', 30),
  ('q1-a4', 'q1', 4, 'mpok', 20),
  ('q1-a5', 'q1', 5, 'mbak', 10),
  ('q2-a1', 'q2', 1, 'Lapar', 50),
  ('q2-a2', 'q2', 2, 'Gabut', 40),
  ('q2-a3', 'q2', 3, 'Karena ingin', 30),
  ('q2-a4', 'q2', 4, 'Bertahan hidup', 20),
  ('q2-a5', 'q2', 5, 'Lagi stress', 10),
  ('q3-a1', 'q3', 1, 'Nasi + nasi goreng', 50),
  ('q3-a2', 'q3', 2, 'Nasi + martabak telor', 40),
  ('q3-a3', 'q3', 3, 'Nasi + siomay', 30),
  ('q3-a4', 'q3', 4, 'Nasi + Citato', 20),
  ('q3-a5', 'q3', 5, 'Nasi + Mie goreng', 10),
  ('q4-a1', 'q4', 1, 'Bangun kesiangan', 50),
  ('q4-a2', 'q4', 2, 'Terjebak macet', 40),
  ('q4-a3', 'q4', 3, 'Nugas sampai begadang', 30),
  ('q4-a4', 'q4', 4, 'Menunggu teman', 20),
  ('q4-a5', 'q4', 5, 'Antre mandi', 10),
  ('q5-a1', 'q5', 1, 'Meminta bantuan ChatGPT', 50),
  ('q5-a2', 'q5', 2, 'Copy-paste pekerjaan teman', 40),
  ('q5-a3', 'q5', 3, 'Mengerjakan dan mengumpulkan seadanya', 30),
  ('q5-a4', 'q5', 4, 'Panik dan overthinking', 20),
  ('q5-a5', 'q5', 5, 'Meminta perpanjangan waktu', 10),
  ('q6-a1', 'q6', 1, 'Bisa tidur tanpa ketahuan', 50),
  ('q6-a2', 'q6', 2, 'Bisa bermain HP', 40),
  ('q6-a3', 'q6', 3, 'Tidak mau ditunjuk dosen', 30),
  ('q6-a4', 'q6', 4, 'Lebih bebas mengobrol', 20),
  ('q6-a5', 'q6', 5, 'Bisa keluar kelas dengan mudah', 10),
  ('q7-a1', 'q7', 1, 'Tugas menumpuk', 50),
  ('q7-a2', 'q7', 2, 'Deadline berdekatan', 40),
  ('q7-a3', 'q7', 3, 'Nilai ujian jelek', 30),
  ('q7-a4', 'q7', 4, 'Masalah keuangan', 20),
  ('q7-a5', 'q7', 5, 'Organisasi dan kepanitiaan', 10);

update public.game_state
set status = 'READY',
    active_question_id = 'q1',
    version = version + 1,
    updated_at = clock_timestamp()
where singleton;

commit;
