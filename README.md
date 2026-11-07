# Top Survey

Aplikasi permainan survei interaktif untuk Host dan layar Display. State game disimpan di Supabase; Host mengubah state melalui API server, sedangkan Display hanya menerima jawaban yang sudah dibuka.

## Menjalankan di komputer lokal

Persyaratan: Node.js 20.9 atau lebih baru, npm, dan proyek Supabase.

1. Pasang dependensi:

   ```bash
   npm install
   ```

2. Salin `.env.example` ke `.env.local`, lalu isi URL Supabase, publishable key, secret key, PIN Host, dan `HOST_RATE_LIMIT_SALT` acak minimal 16 karakter. Jangan pernah menaruh secret key dengan awalan `NEXT_PUBLIC_`.

3. Siapkan database. Untuk Supabase lokal, jalankan `supabase start`; migrasi dan `supabase/seed.sql` akan diterapkan oleh konfigurasi lokal. Seed menyiapkan enam pertanyaan DEMO karangan dengan lima jawaban per pertanyaan agar alur permainan bisa dicoba dari awal sampai akhir. Konten ini bukan hasil survei acara. Untuk proyek Cloud, tinjau dan terapkan migrasi melalui prosedur rilis proyek; jangan gunakan seed demo.

4. Jalankan web:

   ```bash
   npm run dev
   ```

   Buka URL lokal yang ditampilkan Next.js. Host ada di `/host`, layar proyektor di `/display`.

`HOST_PIN` dan `HOST_RATE_LIMIT_SALT` harus tersedia di server. Perubahan konfigurasi env memerlukan server dimulai ulang. Saat development, Next.js dapat memuat `.env.development.local` sebelum `.env.local`.

## Menyiapkan konten acara

Demo lokal berisi enam pertanyaan dan 30 jawaban karangan. Seed menandai konten lokal siap dimainkan agar Start, Next Question, Finish, skor, dan reset dapat dicoba. Di database acara, setiap pertanyaan harus memiliki judul, tepat lima jawaban dengan poin positif, serta `content_verified = true` setelah diperiksa penyelenggara. Jangan gunakan atau menandai konten demo sebagai hasil survei terverifikasi.

## Pemeriksaan dan produksi

```bash
npm run typecheck
npm run build
npm run start
```

Tes database lokal tersedia melalui `supabase test db` setelah Supabase lokal berjalan.
