import { adminClient } from "@/lib/supabase/admin";
import { activeHostTokenHash } from "@/lib/host-auth";
import { hostGame } from "@/lib/game-read";
import { parseGameCommand } from "@/lib/game-command";
import { backendError, gameError, isSameOrigin, json } from "@/lib/http";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const supabase = adminClient();
    if (!(await activeHostTokenHash(supabase))) {
      return json({ error: "Host tidak terotorisasi." }, 401);
    }
    return json(await hostGame(supabase));
  } catch (error) {
    return backendError(error);
  }
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

  const command = parseGameCommand(body);
  if (!command) return json({ error: "Perintah permainan tidak valid." }, 400);

  try {
    const supabase = adminClient();
    const tokenHash = await activeHostTokenHash(supabase);
    if (!tokenHash) return json({ error: "Host tidak terotorisasi." }, 401);

    const { data, error } = await supabase.rpc("apply_game_action", {
      p_token_hash: tokenHash,
      p_request_id: command.requestId,
      p_expected_version: command.expectedVersion,
      p_action: command.action,
      p_question_id: command.questionId ?? null,
      p_answer_id: command.answerId ?? null,
    });

    if (error) {
      // Keep diagnostics useful without ever logging the Host credential/token.
      console.warn("apply_game_action failed", {
        action: command.action,
        expectedVersion: command.expectedVersion,
        code: error.code ?? null,
        message: error.message,
      });
      return gameError(error.message);
    }

    return json(data);
  } catch (error) {
    return backendError(error);
  }
}
