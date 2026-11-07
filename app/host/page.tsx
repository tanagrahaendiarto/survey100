"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { AnswerBoard } from "@/components/answer-board";
import { useGame } from "@/components/use-game";
import type { GameAction } from "@/lib/game-command";
import {
  getGameAudioContext,
  playGameAudio,
  preloadGameAudio,
} from "@/lib/game-audio";
import type { BroadcastSound } from "@/lib/game-audio";

export default function HostPage() {
  const host = useGame(true);
  const [pin, setPin] = useState("");
  const [loginError, setLoginError] = useState("");
  const [takeover, setTakeover] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);
  const [message, setMessage] = useState("Pilih nomor jawaban, lalu buka.");
  const [processing, setProcessing] = useState(false);
  const audioContext = useRef<AudioContext | null>(null);
  const game = host.game;
  const question = game?.question;
  const opened = new Set(game?.revealedAnswerIds ?? []);
  const unavailable = processing || host.connection === "offline";

  useEffect(
    () => () => {
      const context = audioContext.current;
      audioContext.current = null;
      if (context) void context.close();
    },
    [],
  );

  async function login(takeOverHost = false) {
    setLoginError("");
    try {
      const response = await fetch("/api/host/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ pin, takeover: takeOverHost }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) {
        if (body.error === "HOST_IN_USE") setTakeover(true);
        setLoginError(
          body.error === "HOST_IN_USE"
            ? "Host lain masih aktif. Masukkan PIN kembali untuk mengambil alih."
            : (body.error ?? "Login gagal."),
        );
        return;
      }
      setPin("");
      setTakeover(false);
      await host.refresh();
    } catch {
      setLoginError("Backend tidak dapat dijangkau.");
    }
  }

  async function runAction(
    action: GameAction,
    details: { questionId?: string; answerId?: string } = {},
  ) {
    if (processing) return false;
    setProcessing(true);
    const result = await host.act(action, details);
    setProcessing(false);
    const successMessage =
      action === "open_answer"
        ? "Jawaban berhasil dibuka."
        : action === "restart_game"
          ? "Sesi dimulai ulang dari Pertanyaan 1."
          : "Aksi berhasil disimpan.";
    setMessage(
      result.error || (result.ok ? successMessage : "Aksi gagal."),
    );
    if (result.ok) setSelected(null);
    return result.ok;
  }

  async function openAnswer() {
    if (!selected || !question) {
      setMessage("Pilih nomor jawaban terlebih dahulu.");
      return;
    }
    if (opened.has(selected)) {
      setMessage("Jawaban tersebut sudah dibuka.");
      return;
    }
    const context = getGameAudioContext(audioContext.current);
    audioContext.current = context;
    if (context) {
      void context.resume().catch(() => undefined);
      void preloadGameAudio(context, ["correct"]);
    }

    const openedSuccessfully = await runAction("open_answer", {
      questionId: question.id,
      answerId: selected,
    });
    if (!openedSuccessfully) return;

    if (context) void playGameAudio(context, "correct");
    const soundError = await broadcastSound("correct");
    if (soundError) setMessage(`Jawaban dibuka. ${soundError}`);
  }

  async function sendWrong() {
    const sound: BroadcastSound = "wrong";
    const context = getGameAudioContext(audioContext.current);
    audioContext.current = context;
    if (context) {
      void context.resume().catch(() => undefined);
      void preloadGameAudio(context, [sound]);
      void playGameAudio(context, sound);
    }

    const soundError = await broadcastSound(sound);
    setMessage(soundError || "Tanda jawaban salah dikirim ke Display.");
  }

  async function broadcastSound(sound: BroadcastSound) {
    try {
      const response = await fetch("/api/host/sound", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sound }),
      });
      const body = (await response.json()) as { error?: string };
      return response.ok ? "" : (body.error ?? "Event soundboard gagal.");
    } catch {
      return "Backend tidak dapat dijangkau.";
    }
  }

  async function startGame() {
    if (!window.confirm("Mulai sesi dari Pertanyaan 1?")) return;
    await runAction("start_game");
  }

  async function nextQuestion() {
    if (
      !game ||
      !window.confirm(`Lanjut ke Pertanyaan ${question!.position + 1}?`)
    )
      return;
    await runAction("next_question");
  }

  async function resetQuestion() {
    if (
      !window.confirm(
        "Tutup kembali semua jawaban pada pertanyaan ini?",
      )
    )
      return;
    await runAction("reset_question");
  }

  async function restartGame() {
    if (
      !window.confirm(
        "Ulang dari Pertanyaan 1? Semua jawaban yang sudah dibuka akan ditutup.",
      )
    )
      return;
    await runAction("restart_game");
  }

  async function finishGame() {
    if (!window.confirm("Akhiri sesi setelah pertanyaan ini?")) return;
    await runAction("finish_game");
  }

  async function logout() {
    await fetch("/api/host/session", { method: "DELETE" });
    await host.refresh();
  }

  useEffect(() => {
    const currentGame = game;
    if (!host.authorized || !currentGame) return;
    const currentQuestion = currentGame.question;
    const questionCount = currentGame.questionCount;

    function onKeyDown(event: KeyboardEvent) {
      const target = event.target as HTMLElement;
      if (
        ["INPUT", "TEXTAREA"].includes(target.tagName) ||
        target.isContentEditable
      )
        return;

      if (event.ctrlKey && event.key.toLowerCase() === "z") {
        event.preventDefault();
        void runAction("undo");
        return;
      }
      if (event.ctrlKey && event.key.toLowerCase() === "y") {
        event.preventDefault();
        void runAction("redo");
        return;
      }
      if (/^[1-5]$/.test(event.key)) {
        setSelected(currentQuestion.answers[Number(event.key) - 1]?.id ?? null);
      } else if (event.key === "Enter") {
        void openAnswer();
      } else if (event.key.toLowerCase() === "x") {
        void sendWrong();
      } else if (event.key === "Escape") {
        setSelected(null);
      } else if (
        event.key.toLowerCase() === "n" &&
        currentQuestion.position < questionCount
      ) {
        void nextQuestion();
      } else if (event.key.toLowerCase() === "r") {
        void resetQuestion();
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  if (!host.authorized) {
    return (
      <main className="app-shell">
        <header className="app-nav">
          <Link className="nav-brand" href="/">
            <span className="brand-mark">TS</span> TOP SURVEY
          </Link>
          <Link href="/">Keluar</Link>
        </header>
        <section className="control-card host-login">
          <div className="kicker">AKSES OPERATOR</div>
          <h1 className="question-title">Masuk ke Host</h1>
          <p className="control-note">
            Masukkan PIN Host untuk mengatur pembukaan jawaban.
          </p>
          <form
            onSubmit={(event) => {
              event.preventDefault();
              void login();
            }}
          >
            <label className="login-label" htmlFor="host-pin">
              PIN Host
            </label>
            <input
              id="host-pin"
              className="pin-input"
              type="password"
              inputMode="numeric"
              autoComplete="current-password"
              value={pin}
              onChange={(event) => setPin(event.target.value)}
            />
            {loginError && (
              <p className="login-error" role="alert">
                {loginError}
              </p>
            )}
            {host.error && (
              <p className="login-error" role="alert">
                {host.error}
              </p>
            )}
            <button
              className="small-button login-submit"
              type="submit"
              disabled={!pin}
            >
              Masuk sebagai Host
            </button>
          </form>
          {takeover && (
            <button
              className="danger-button login-takeover"
              onClick={() => void login(true)}
              disabled={!pin}
            >
              Ambil alih Host dengan PIN
            </button>
          )}
          <p className="notice">
            Host lease diperbarui otomatis. Jika Host lama terputus, lease
            kedaluwarsa setelah 60 detik.
          </p>
        </section>
      </main>
    );
  }

  if (!game || !question) {
    return (
      <main className="app-shell">
        <header className="app-nav">
          <Link className="nav-brand" href="/">
            <span className="brand-mark">TS</span> TOP SURVEY
          </Link>
          <button className="small-button" onClick={() => void logout()}>
            Logout
          </button>
        </header>
        <section className="control-card">
          <p>{host.error || "Memuat game…"}</p>
          <button className="small-button" onClick={() => void host.refresh()}>
            Coba lagi
          </button>
        </section>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <header className="app-nav">
        <Link className="nav-brand" href="/">
          <span className="brand-mark">TS</span> TOP SURVEY
        </Link>
        <nav className="nav-links">
          <span className="demo-pill">
            {host.connection === "offline"
              ? "OFFLINE"
              : host.realtime === "connected"
                ? "LIVE"
                : "DB ONLINE"}
          </span>
          <Link href="/display" target="_blank">
            Buka Display ↗
          </Link>
          <button className="text-button" onClick={() => void logout()}>
            Logout
          </button>
        </nav>
      </header>
      <div className="page-heading">
        <div>
          <div className="kicker">PANEL OPERATOR · UNPAD × IPB</div>
          <h1>Panel Host</h1>
        </div>
        <span className="question-count">
          {game.status === "READY"
            ? "SIAP DIMULAI"
            : `PERTANYAAN ${String(question.position).padStart(2, "0")} / ${String(game.questionCount).padStart(2, "0")}`}
        </span>
      </div>
      {host.error && (
        <p className="action-error" role="alert">
          {host.error}
        </p>
      )}
      <div className="workspace">
        <div>
          <AnswerBoard state={game} />
        </div>
        <aside className="host-side">
          <section className="control-card">
            <h2 className="control-title">Buka jawaban</h2>
            <p className="control-note">
              Pilih nomor jawaban, lalu buka untuk ditampilkan di Display.
            </p>
            <div className="number-grid">
              {[1, 2, 3, 4, 5].map((position) => {
                const answer = question.answers.find(
                  (item) => item.position === position,
                );
                const isOpen = answer ? opened.has(answer.id) : false;
                return (
                  <button
                    className={`number-key ${selected === answer?.id ? "selected" : ""}`}
                    key={position}
                    onClick={() => setSelected(answer?.id ?? null)}
                    disabled={
                      unavailable ||
                      game.status !== "IN_PROGRESS" ||
                      !answer ||
                      isOpen
                    }
                  >
                    {position}
                  </button>
                );
              })}
            </div>
            <button
              className="small-button full-width action-primary"
              onClick={() => void openAnswer()}
              disabled={
                unavailable ||
                game.status !== "IN_PROGRESS" ||
                !selected ||
                opened.has(selected)
              }
            >
              Buka jawaban · Enter
            </button>
            <p className="selection-note" role="status">
              {message}
            </p>
            <div className="control-divider" />
            <div className="utility-grid">
              <button
                className="small-button wrong-button"
                onClick={() => void sendWrong()}
                disabled={unavailable}
              >
                X · Salah
              </button>
              <button
                className="small-button"
                onClick={() => void runAction("undo")}
                disabled={unavailable || !game.canUndo}
              >
                Undo
              </button>
              <button
                className="small-button"
                onClick={() => void runAction("redo")}
                disabled={unavailable || !game.canRedo}
              >
                Redo
              </button>
            </div>
          </section>
          <section className="control-card">
            <h2 className="control-title">Pertanyaan</h2>
            <p className="control-note">
              Perpindahan pertanyaan mengikuti arahan MC dan dikendalikan Host.
            </p>
            {game.status === "READY" ? (
              <>
                <button
                  className="small-button full-width action-primary"
                  onClick={() => void startGame()}
                  disabled={!game.contentReady || unavailable}
                >
                  Mulai sesi
                </button>
                {!!game.contentIssues?.length && (
                  <ul className="content-issues">
                    {game.contentIssues.map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                )}
              </>
            ) : game.status === "COMPLETED" ? (
              <div className="question-actions">
                <p className="control-note">Semua pertanyaan sudah selesai.</p>
                <button
                  className="small-button action-primary"
                  onClick={() => void restartGame()}
                  disabled={unavailable}
                >
                  Ulang dari Pertanyaan 1
                </button>
              </div>
            ) : (
              <div className="question-actions">
                {question.position < game.questionCount ? (
                  <button
                    className="small-button action-primary"
                    onClick={() => void nextQuestion()}
                    disabled={unavailable}
                  >
                    Pertanyaan berikutnya · N
                  </button>
                ) : (
                  <button
                    className="small-button action-primary"
                    onClick={() => void finishGame()}
                    disabled={unavailable}
                  >
                    Selesaikan sesi
                  </button>
                )}
                <button
                  className="danger-button"
                  onClick={() => void resetQuestion()}
                  disabled={unavailable}
                >
                  Reset pertanyaan · R
                </button>
                <button
                  className="small-button"
                  onClick={() => void restartGame()}
                  disabled={unavailable}
                >
                  Ulang dari Pertanyaan 1
                </button>
              </div>
            )}
            <div className="secondary-actions">
              <button
                className="small-button"
                onClick={() => window.open("/display", "_blank")}
              >
                Buka Display ↗
              </button>
            </div>
            <div className="notice">
              State tersimpan di Supabase. Host memperbarui lease setiap 15
              detik.
            </div>
          </section>
        </aside>
      </div>
    </main>
  );
}
