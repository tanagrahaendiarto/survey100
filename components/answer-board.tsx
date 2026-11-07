import type { GameView } from "@/lib/game-types";

export function AnswerBoard({
  state,
  display = false,
}: {
  state: GameView;
  display?: boolean;
}) {
  const { question } = state;
  const questionCount = String(state.questionCount).padStart(2, "0");

  if (display) {
    const opened = new Map(
      (state.revealedAnswers ?? []).map((answer) => [answer.position, answer]),
    );
    return (
      <section className="display-board" aria-label="Papan permainan">
        <div className="display-kicker">
          PERTANYAAN {String(question.position).padStart(2, "0")} / {questionCount}
        </div>
        <h1 className="display-question">{question.title}</h1>
        <div className="display-answers">
          {[1, 2, 3, 4, 5].map((position) => {
            const answer = opened.get(position);
            return (
              <div
                className={`display-answer ${answer ? "open" : ""}`}
                key={position}
              >
                <span className="display-number">
                  {String(position).padStart(2, "0")}
                </span>
                <span className="display-answer-text">
                  {answer?.text ?? ""}
                </span>
              </div>
            );
          })}
        </div>
        <div className="display-footer">
          <span>STUDI BANDING 2026</span>
        </div>
      </section>
    );
  }

  const opened = new Set(state.revealedAnswerIds);
  return (
    <section className="board-card">
      <div className="board-top">
        <div>
          <div className="board-label">
            PERTANYAAN {String(question.position).padStart(2, "0")} / {questionCount}
          </div>
          <h2 className="question-title">{question.title}</h2>
        </div>
        <span className="status-pill">{state.status}</span>
      </div>
      <div className="answer-list">
        {question.answers.map((answer) => {
          const isOpen = opened.has(answer.id);
          return (
            <div
              className={`answer-row ${isOpen ? "revealed" : ""}`}
              key={answer.id}
            >
              <span className="answer-number">{answer.position}</span>
              <span className="answer-text">{answer.text}</span>
            </div>
          );
        })}
        {question.answers.length === 0 && (
          <div className="empty-q">
            Jawaban untuk pertanyaan ini belum tersedia.
          </div>
        )}
      </div>
      <div className="board-foot">
        <span>{opened.size} / 5 JAWABAN TERBUKA</span>
        <span>TOP SURVEY · UNPAD × IPB</span>
      </div>
    </section>
  );
}
