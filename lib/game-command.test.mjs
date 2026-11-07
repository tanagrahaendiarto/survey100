import assert from "node:assert/strict";
import test from "node:test";
import { parseGameCommand } from "./game-command.ts";

const requestId = "00000000-0000-4000-8000-000000000001";

test("accepts a reveal command without team or point details", () => {
  assert.deepEqual(
    parseGameCommand({
      requestId,
      expectedVersion: 2,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
    }),
    {
      requestId,
      expectedVersion: 2,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
    },
  );
});

test("rejects invalid versions, IDs, and actions", () => {
  const base = { requestId, expectedVersion: 0, action: "start_game" };
  assert.equal(parseGameCommand({ ...base, expectedVersion: -1 }), null);
  assert.equal(parseGameCommand({ ...base, expectedVersion: 0.5 }), null);
  assert.equal(parseGameCommand({ ...base, requestId: "bad" }), null);
  assert.equal(parseGameCommand({ ...base, action: "award_points" }), null);
  assert.deepEqual(
    parseGameCommand({
      ...base,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
    }),
    {
      requestId,
      expectedVersion: 0,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
    },
  );
  assert.equal(
    parseGameCommand({
      ...base,
      action: "open_answer",
      questionId: "",
      answerId: "q1-a1",
    }),
    null,
  );
});

test("requires answer details only for reveal commands", () => {
  assert.deepEqual(
    parseGameCommand({ requestId, expectedVersion: 0, action: "undo" }),
    {
      requestId,
      expectedVersion: 0,
      action: "undo",
    },
  );
  assert.equal(
    parseGameCommand({ requestId, expectedVersion: 0, action: "open_answer" }),
    null,
  );
  assert.deepEqual(
    parseGameCommand({ requestId, expectedVersion: 0, action: "restart_game" }),
    {
      requestId,
      expectedVersion: 0,
      action: "restart_game",
    },
  );
});
