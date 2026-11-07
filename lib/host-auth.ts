import "server-only";
import { createHash } from "node:crypto";
import { cookies } from "next/headers";
import type { SupabaseClient } from "@supabase/supabase-js";

export const hostCookieName = "top_survey_host";

export function hashToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

export async function activeHostTokenHash(supabase: SupabaseClient) {
  const token = (await cookies()).get(hostCookieName)?.value;
  if (!token) return null;

  const tokenHash = hashToken(token);
  const { data, error } = await supabase.rpc("host_session_is_active", {
    p_token_hash: tokenHash,
  });
  if (error) throw error;
  return data ? tokenHash : null;
}
