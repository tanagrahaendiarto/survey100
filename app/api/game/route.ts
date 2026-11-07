import { adminClient } from "@/lib/supabase/admin";
import { publicGame } from "@/lib/game-read";
import { backendError, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    return json(await publicGame(adminClient()));
  } catch (error) {
    return backendError(error);
  }
}
