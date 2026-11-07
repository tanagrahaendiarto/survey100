const actions = [
  "start_game",
  "open_answer",
  "undo",
  "redo",
  "next_question",
  "finish_game",
  "reset_question",
  "reset_game",
] as const;

export type GameAction = (typeof actions)[number];

export type GameCommand = {
  requestId: string;
  expectedVersion: number;
  action: GameAction;
  questionId?: string;
  answerId?: string;
  team?: "A" | "B";
};

export function parseGameCommand(input: unknown): GameCommand | null {
  if (!input || typeof input !== "object") return null;

  const body = input as Record<string, unknown>;
  if (
    typeof body.requestId !== "string" ||
    !/^[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}$/i.test(body.requestId) ||
    typeof body.expectedVersion !== "number" ||
    !Number.isSafeInteger(body.expectedVersion) ||
    body.expectedVersion < 0 ||
    typeof body.action !== "string" ||
    !actions.includes(body.action as GameAction)
  ) {
    return null;
  }

  const command: GameCommand = {
    requestId: body.requestId,
    expectedVersion: body.expectedVersion,
    action: body.action as GameAction,
  };

  if (command.action !== "open_answer") return command;
  if (
    typeof body.questionId !== "string" ||
    body.questionId.length === 0 ||
    body.questionId.length > 80 ||
    typeof body.answerId !== "string" ||
    body.answerId.length === 0 ||
    body.answerId.length > 80 ||
    (body.team !== "A" && body.team !== "B")
  ) {
    return null;
  }

  return {
    ...command,
    questionId: body.questionId,
    answerId: body.answerId,
    team: body.team,
  };
}
