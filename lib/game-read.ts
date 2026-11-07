import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";

type Snapshot = {
  status: "READY" | "IN_PROGRESS" | "COMPLETED";
  activeQuestionId: string;
  questionCount: number;
  version: number;
  scores: { A: number; B: number };
  revealedAnswerIds: string[];
};

async function snapshot(supabase: SupabaseClient): Promise<Snapshot> {
  const { data, error } = await supabase.rpc("game_snapshot");
  if (error) throw error;
  if (!data) throw new Error("GAME_NOT_INITIALIZED");
  return data as Snapshot;
}

async function question(supabase: SupabaseClient, id: string) {
  const { data, error } = await supabase
    .from("questions")
    .select("id, position, title")
    .eq("id", id)
    .single();
  if (error) throw error;
  return data;
}

export async function publicGame(supabase: SupabaseClient) {
  const state = await snapshot(supabase);
  const active = await question(supabase, state.activeQuestionId);
  let answers: {
    id: string;
    position: number;
    text: string;
    points: number;
  }[] = [];

  if (state.revealedAnswerIds.length) {
    const { data, error } = await supabase
      .from("revealed_answers")
      .select("answer_id, answer_position, answer_text, points_awarded")
      .eq("question_id", active.id)
      .order("answer_position");
    if (error) throw error;
    answers = (data ?? []).map((answer) => ({
      id: answer.answer_id,
      position: answer.answer_position,
      text: answer.answer_text,
      points: answer.points_awarded,
    }));
  }

  return {
    ...state,
    question: {
      id: active.id,
      position: active.position,
      title: active.title || "Menunggu materi survei dari UNPAD.",
      answers: [],
    },
    revealedAnswers: answers,
  };
}

export async function hostGame(supabase: SupabaseClient) {
  const state = await snapshot(supabase);
  const { data, error: questionsError } = await supabase
    .from("questions")
    .select(
      "id, position, title, content_verified, answers(id, position, answer_text, points)",
    )
    .order("position");
  if (questionsError) throw questionsError;

  const questions = (data ?? []).map((item) => ({
    id: item.id,
    position: item.position,
    title: item.title || "Menunggu materi survei dari UNPAD.",
    contentVerified: item.content_verified,
    answers: (item.answers ?? []).map((answer) => ({
      id: answer.id,
      position: answer.position,
      text: answer.answer_text,
      points: answer.points,
    })),
  }));
  const current = questions.find((item) => item.id === state.activeQuestionId);
  if (!current) throw new Error("ACTIVE_QUESTION_NOT_FOUND");

  let revealedAnswers: {
    answer_id: string;
    answer_position: number;
    answer_text: string;
    points_awarded: number;
  }[] = [];
  if (state.revealedAnswerIds.length) {
    const { data: opened, error: openedError } = await supabase
      .from("revealed_answers")
      .select("answer_id, answer_position, answer_text, points_awarded")
      .eq("question_id", state.activeQuestionId);
    if (openedError) throw openedError;
    revealedAnswers = opened ?? [];
  }
  const openedById = new Map(
    revealedAnswers.map((answer) => [answer.answer_id, answer]),
  );
  const activeQuestion = {
    ...current,
    answers: current.answers.map((answer) => {
      const opened = openedById.get(answer.id);
      return opened
        ? {
            ...answer,
            position: opened.answer_position,
            text: opened.answer_text,
            points: opened.points_awarded,
          }
        : answer;
    }),
  };

  const positionsAreContiguous = questions.every(
    (item, index) => item.position === index + 1,
  );
  const contentIssues =
    questions.length === 0
      ? ["Harus tersedia minimal satu pertanyaan"]
      : [
          ...(!positionsAreContiguous
            ? ["Nomor pertanyaan harus berurutan mulai dari 1"]
            : []),
          ...questions.flatMap((item) => [
            ...(!item.title.trim() || item.title.startsWith("Menunggu materi")
              ? [`Q${item.position}: pertanyaan belum diisi`]
              : []),
            ...(item.answers.length !== 5
              ? [`Q${item.position}: harus memiliki tepat 5 jawaban`]
              : []),
            ...(!item.contentVerified
              ? [`Q${item.position}: konten belum diverifikasi`]
              : []),
            ...(item.answers.some(
              (answer) => !answer.text.trim() || answer.points <= 0,
            )
              ? [`Q${item.position}: teks dan poin jawaban harus valid`]
              : []),
          ]),
        ];

  const { data: actions, error: actionsError } = await supabase
    .from("game_actions")
    .select("status")
    .eq("question_id", state.activeQuestionId);
  if (actionsError) throw actionsError;

  return {
    ...state,
    question: activeQuestion,
    questions,
    contentReady: contentIssues.length === 0,
    contentIssues,
    canUndo: actions?.some((action) => action.status === "applied") ?? false,
    canRedo: actions?.some((action) => action.status === "undone") ?? false,
  };
}
