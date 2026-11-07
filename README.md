# Top Survey

Aplikasi papan jawaban survei untuk Host dan layar Display. State disimpan di Supabase; Host membuka jawaban melalui API server, sedangkan Display hanya menerima jawaban yang sudah dibuka.

## Menjalankan di komputer lokal

Persyaratan: Node.js 24.x, npm, dan proyek Supabase. Versi ini dipakai agar cocok dengan Supabase JS yang digunakan project.

1. Pasang dependensi:

   ```bash
   npm install
   ```

2. Salin `.env.example` ke `.env.local`, lalu isi URL Supabase, publishable key, secret key, PIN Host, dan `HOST_RATE_LIMIT_SALT` acak minimal 16 karakter. Jangan pernah menaruh secret key dengan awalan `NEXT_PUBLIC_`.

3. Siapkan database. Untuk Supabase lokal, jalankan `supabase start`; migrasi dan `supabase/seed.sql` akan diterapkan oleh konfigurasi lokal. Seed menyiapkan tujuh pertanyaan DEMO karangan dengan lima jawaban per pertanyaan agar alur bisa dicoba dari awal sampai akhir. Konten ini bukan hasil survei acara. Untuk proyek Cloud, tinjau dan terapkan migrasi melalui prosedur rilis proyek; jangan gunakan seed demo.

4. Jalankan web:

   ```bash
   npm run dev
   ```

   Buka URL lokal yang ditampilkan Next.js. Host ada di `/host`, layar proyektor di `/display`.

`HOST_PIN` dan `HOST_RATE_LIMIT_SALT` harus tersedia di server. Perubahan konfigurasi env memerlukan server dimulai ulang. Saat development, Next.js dapat memuat `.env.development.local` sebelum `.env.local`.

## Menyiapkan konten acara

Setup tes berisi tujuh pertanyaan dengan lima jawaban per pertanyaan. Tidak ada poin atau pengelompokan tim; Host dapat membuka jawaban dan mengulang sesi dari Pertanyaan 1. Set `content_verified = true` hanya setelah penyelenggara memeriksa pertanyaan dan jawaban.

## Pemeriksaan dan produksi

```bash
npm run typecheck
npm run build
npm run start
```

Tes database lokal tersedia melalui `supabase test db` setelah Supabase lokal berjalan.

## Deploy ke Vercel

Import repo GitHub ini sebagai project Next.js dengan Root Directory `./`. Vercel mendeteksi build Next.js secara otomatis. Tambahkan environment variables berikut di pengaturan project Vercel (minimal untuk Production):

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SECRET_KEY
HOST_PIN
HOST_RATE_LIMIT_SALT
```

Gunakan nilai Supabase Cloud dari `.env.local`, bukan `.env.development.local`. Jangan commit atau membagikan nilai rahasia. `SUPABASE_DB_PASSWORD` dan `SUPABASE_DB_URL` hanya untuk operasi CLI/migrasi—jangan masukkan ke Vercel. Pastikan `SUPABASE_SECRET_KEY` tetap server-only dan tidak diberi prefix `NEXT_PUBLIC_`.
