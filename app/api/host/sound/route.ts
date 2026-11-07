import { randomUUID } from "node:crypto";
import { adminClient } from "@/lib/supabase/admin";
import { activeHostTokenHash } from "@/lib/host-auth";
import { backendError, isSameOrigin, json } from "@/lib/http";
import type { BroadcastSound } from "@/lib/game-audio";

function isBroadcastSound(value: unknown): value is BroadcastSound {
  return value === "correct" || value === "wrong-a" || value === "wrong-b";
}

export async function POST(request: Request) {
  if (!isSameOrigin(request))
    return json({ error: "Origin tidak diizinkan." }, 403);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Body JSON tidak valid." }, 400);
  }

  const sound =
    typeof body === "object" && body !== null && "sound" in body
      ? body.sound
      : null;
  if (!isBroadcastSound(sound)) {
    return json({ error: "Efek suara tidak valid." }, 400);
  }

  try {
    const supabase = adminClient();
    if (!(await activeHostTokenHash(supabase))) {
      return json({ error: "Host tidak terotorisasi." }, 401);
    }

    const channel = supabase.channel("top-survey:main", {
      config: { private: true },
    });
    try {
      const result = await channel.httpSend("sound", {
        eventId: randomUUID(),
        sound,
        sentAt: new Date().toISOString(),
      });
      if (!result.success)
        return json({ error: "Event soundboard gagal dikirim." }, 502);
    } finally {
      await supabase.removeChannel(channel);
    }

    return json({ ok: true });
  } catch (error) {
    return backendError(error);
  }
}
