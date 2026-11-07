export type GameStatus = "READY" | "IN_PROGRESS" | "COMPLETED";

export type GameAnswer = {
  id: string;
  position: number;
  text: string;
};

export type GameView = {
  status: GameStatus;
  activeQuestionId: string;
  questionCount: number;
  version: number;
  question: {
    id: string;
    position: number;
    title: string;
    answers: GameAnswer[];
  };
  revealedAnswerIds: string[];
  revealedAnswers?: GameAnswer[];
  questions?: {
    id: string;
    position: number;
    title: string;
    contentVerified: boolean;
    answers: GameAnswer[];
  }[];
  contentReady?: boolean;
  contentIssues?: string[];
  canUndo?: boolean;
  canRedo?: boolean;
};
