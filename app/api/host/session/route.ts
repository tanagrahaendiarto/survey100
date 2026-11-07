import {
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto";
import { cookies } from "next/headers";
import { adminClient } from "@/lib/supabase/admin";
import { hashToken, hostCookieName } from "@/lib/host-auth";
import { backendError, isSameOrigin, json } from "@/lib/http";

export const dynamic = "force-dynamic";

function rateLimitKey(request: Request) {
  const salt = process.env.HOST_RATE_LIMIT_SALT;
  if (!salt || salt.length < 16)
    throw new Error("HOST_SECURITY_NOT_CONFIGURED");
  // shortcut: forwarded IP headers must be set by the trusted deployment proxy.
  const address =
    request.headers.get("x-real-ip") ??
    request.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
    "unknown";
  return createHmac("sha256", salt).update(address).digest("hex");
}

function pinMatches(candidate: string, expected: string) {
  const actualBytes = Buffer.from(candidate);
  const expectedBytes = Buffer.from(expected);
  return (
    actualBytes.length === expectedBytes.length &&
    timingSafeEqual(actualBytes, expectedBytes)
  );
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

  if (!body || typeof body !== "object")
    return json({ error: "Data login tidak valid." }, 400);
  const { pin, takeover } = body as { pin?: unknown; takeover?: unknown };
  if (
    typeof pin !== "string" ||
    pin.length < 4 ||
    pin.length > 32 ||
    (takeover !== undefined && typeof takeover !== "boolean")
  ) {
    return json({ error: "PIN atau opsi takeover tidak valid." }, 400);
  }

  const expectedPin = process.env.HOST_PIN;
  if (!expectedPin || expectedPin.length < 4 || expectedPin.length > 32)
    return json({ error: "PIN Host belum dikonfigurasi di server." }, 503);

  try {
    const supabase = adminClient();
    const keyHash = rateLimitKey(request);
    const { data: allowed, error: limitError } = await supabase.rpc(
      "consume_host_pin_attempt",
      {
        p_key_hash: keyHash,
      },
    );
    if (limitError) throw limitError;
    if (!allowed)
      return json(
        { error: "Terlalu banyak percobaan. Coba lagi 15 menit." },
        429,
      );

    if (!pinMatches(pin, expectedPin))
      return json({ error: "PIN Host salah." }, 401);

    const { error: clearError } = await supabase.rpc(
      "clear_host_pin_attempts",
      {
        p_key_hash: keyHash,
      },
    );
    if (clearError) throw clearError;

    const token = randomBytes(32).toString("hex");
    const tokenHash = hashToken(token);
    const { data: lease, error: leaseError } = await supabase.rpc(
      "acquire_host_lease",
      {
        p_token_hash: tokenHash,
        p_takeover: takeover === true,
      },
    );
    if (leaseError) throw leaseError;
    if (!lease?.ok) return json({ error: "HOST_IN_USE" }, 409);

    (await cookies()).set(hostCookieName, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/",
      maxAge: 8 * 60 * 60,
    });

    return json({ ok: true, expiresAt: lease.expiresAt });
  } catch (error) {
    return backendError(error);
  }
}

export async function PATCH(request: Request) {
  if (!isSameOrigin(request))
    return json({ error: "Origin tidak diizinkan." }, 403);

  try {
    const token = (await cookies()).get(hostCookieName)?.value;
    if (!token) return json({ error: "Host tidak terotorisasi." }, 401);

    const { data, error } = await adminClient().rpc("heartbeat_host_lease", {
      p_token_hash: createHash("sha256").update(token).digest("hex"),
    });
    if (error?.message === "HOST_LEASE_EXPIRED")
      return json(
        { error: "Host lease kedaluwarsa. Login atau takeover kembali." },
        401,
      );
    if (error) throw error;
    return json({ ok: true, expiresAt: data });
  } catch (error) {
    return backendError(error);
  }
}

export async function DELETE(request: Request) {
  if (!isSameOrigin(request))
    return json({ error: "Origin tidak diizinkan." }, 403);

  try {
    const cookieStore = await cookies();
    const token = cookieStore.get(hostCookieName)?.value;
    if (token) {
      const { error } = await adminClient().rpc("release_host_lease", {
        p_token_hash: createHash("sha256").update(token).digest("hex"),
      });
      if (error) throw error;
    }
    cookieStore.delete(hostCookieName);
    return json({ ok: true });
  } catch (error) {
    return backendError(error);
  }
}
