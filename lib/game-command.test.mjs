import assert from "node:assert/strict";
import test from "node:test";
import { parseGameCommand } from "./game-command.ts";

const requestId = "00000000-0000-4000-8000-000000000001";

test("accepts a valid reveal command", () => {
  assert.deepEqual(
    parseGameCommand({
      requestId,
      expectedVersion: 2,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
      team: "A",
    }),
    {
      requestId,
      expectedVersion: 2,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
      team: "A",
    },
  );
});

test("rejects invalid versions, IDs, actions, and teams", () => {
  const base = { requestId, expectedVersion: 0, action: "start_game" };
  assert.equal(parseGameCommand({ ...base, expectedVersion: -1 }), null);
  assert.equal(parseGameCommand({ ...base, expectedVersion: 0.5 }), null);
  assert.equal(parseGameCommand({ ...base, requestId: "bad" }), null);
  assert.equal(parseGameCommand({ ...base, action: "award_points" }), null);
  assert.equal(
    parseGameCommand({
      ...base,
      action: "open_answer",
      questionId: "q1",
      answerId: "q1-a1",
      team: "C",
    }),
    null,
  );
  assert.equal(
    parseGameCommand({
      ...base,
      action: "open_answer",
      questionId: "",
      answerId: "q1-a1",
      team: "A",
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
});
