export function json(data: unknown, status = 200) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

export function isSameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  // shortcut: trusts forwarded-host from the deployment proxy; configure a trusted proxy when self-hosting.
  const host =
    request.headers.get("x-forwarded-host") ?? request.headers.get("host");
  if (!origin || !host) return false;

  try {
    return new URL(origin).host === host.split(",")[0].trim();
  } catch {
    return false;
  }
}

export function backendError(error: unknown) {
  if (error instanceof Error && error.message === "SUPABASE_NOT_CONFIGURED") {
    return json({ error: "Supabase belum dikonfigurasi." }, 503);
  }
  return json({ error: "Backend tidak dapat memproses permintaan." }, 503);
}

const gameErrors: Record<string, { status: number; message: string }> = {
  ANSWER_ALREADY_OPEN: {
    status: 409,
    message: "Jawaban tersebut sudah dibuka.",
  },
  ANSWER_NOT_FOUND: { status: 404, message: "Jawaban tidak ditemukan." },
  CONTENT_NOT_READY: {
    status: 422,
    message: "Konten pertanyaan belum lengkap atau diverifikasi.",
  },
  GAME_NOT_INITIALIZED: {
    status: 503,
    message: "Game belum diinisialisasi di database.",
  },
  HOST_LEASE_EXPIRED: {
    status: 401,
    message: "Sesi Host kedaluwarsa. Login kembali.",
  },
  INVALID_ACTION: { status: 400, message: "Aksi permainan tidak dikenal." },
  INVALID_COMMAND: { status: 400, message: "Data aksi permainan tidak valid." },
  INVALID_GAME_STATUS: {
    status: 409,
    message: "Aksi tidak berlaku pada status game saat ini.",
  },
  NO_NEXT_QUESTION: {
    status: 409,
    message: "Tidak ada pertanyaan berikutnya.",
  },
  REDO_EMPTY: { status: 409, message: "Tidak ada aksi untuk di-Redo." },
  REQUEST_ID_REUSED: {
    status: 409,
    message: "ID aksi sudah digunakan untuk perintah berbeda.",
  },
  STALE_STATE: {
    status: 409,
    message: "State game berubah. Muat ulang state terbaru.",
  },
  UNDO_EMPTY: {
    status: 409,
    message: "Tidak ada aksi untuk di-Undo pada pertanyaan ini.",
  },
  UNDO_STATE_MISMATCH: {
    status: 409,
    message: "Riwayat Undo tidak cocok dengan state game.",
  },
};

export function gameError(message: string) {
  const known = gameErrors[message];
  if (known) return json({ code: message, error: known.message }, known.status);
  return json({ error: "Aksi game gagal diproses." }, 500);
}
