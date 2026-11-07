"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { AnswerBoard } from "@/components/answer-board";
import { useGame } from "@/components/use-game";
import { browserClient } from "@/lib/supabase/browser";
import {
  getGameAudioContext,
  playGameAudio,
  preloadGameAudio,
} from "@/lib/game-audio";

export default function DisplayPage() {
  const { game, connection, realtime, error } = useGame();
  const [wrong, setWrong] = useState(false);
  const [audioEnabled, setAudioEnabled] = useState(false);
  const audioEnabledRef = useRef(false);
  const audioContext = useRef<AudioContext | null>(null);
  const wrongFlashTimer = useRef<number | null>(null);
  const previousStatus = useRef<string | null>(null);
  const pendingCompletionSound = useRef(false);

  useEffect(() => {
    const supabase = browserClient();
    if (!supabase) return;

    const seen = new Set<string>();
    const channel = supabase
      .channel("top-survey:main", { config: { private: true } })
      .on("broadcast", { event: "sound" }, ({ payload }) => {
        const eventId = payload?.eventId;
        const sound = payload?.sound;
        if (
          typeof eventId !== "string" ||
          seen.has(eventId) ||
          (sound !== "correct" && sound !== "wrong")
        )
          return;
        seen.add(eventId);
        if (seen.size > 100) seen.delete(seen.values().next().value!);
        if (sound === "wrong") {
          setWrong(true);
          if (wrongFlashTimer.current !== null) {
            window.clearTimeout(wrongFlashTimer.current);
          }
          wrongFlashTimer.current = window.setTimeout(() => {
            wrongFlashTimer.current = null;
            setWrong(false);
          }, 800);
        }
        if (
          audioEnabledRef.current &&
          audioContext.current?.state === "running"
        ) {
          void playGameAudio(audioContext.current, sound);
        }
      })
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, []);

  const gameStatus = game?.status ?? null;
  useEffect(() => {
    if (!gameStatus) return;

    const previous = previousStatus.current;
    previousStatus.current = gameStatus;

    if (gameStatus !== "COMPLETED") {
      pendingCompletionSound.current = false;
      return;
    }
    if (!previous || previous === "COMPLETED") return;

    const context = audioContext.current;
    if (audioEnabledRef.current && context?.state === "running") {
      pendingCompletionSound.current = false;
      void playGameAudio(context, "game-complete");
    } else {
      pendingCompletionSound.current = true;
    }
  }, [gameStatus]);

  async function toggleAudio() {
    if (audioEnabled) {
      audioEnabledRef.current = false;
      setAudioEnabled(false);
      return;
    }

    try {
      const context = getGameAudioContext(audioContext.current);
      if (!context) throw new Error("Audio tidak didukung browser ini.");
      audioContext.current = context;
      await context.resume();
      audioEnabledRef.current = true;
      setAudioEnabled(true);
      void preloadGameAudio(context, [
        "correct",
        "wrong",
        "game-complete",
      ]);
      if (pendingCompletionSound.current) {
        pendingCompletionSound.current = false;
        void playGameAudio(context, "game-complete");
      }
    } catch {
      audioEnabledRef.current = false;
      setAudioEnabled(false);
    }
  }

  useEffect(
    () => () => {
      audioEnabledRef.current = false;
      if (wrongFlashTimer.current !== null) {
        window.clearTimeout(wrongFlashTimer.current);
      }
      if (audioContext.current) void audioContext.current.close();
    },
    [],
  );

  return (
    <main className={`display-shell ${wrong ? "wrong-flash" : ""}`}>
      <header className="display-header">
        <Link className="nav-brand" href="/">
          <span className="brand-mark">TS</span> TOP SURVEY
        </Link>
        <span className="display-event">
          STUDI BANDING <b>UNPAD × IPB</b>
        </span>
        <span className="display-state">
          {connection === "offline"
            ? "OFFLINE"
            : realtime === "connected"
              ? "LIVE"
              : "MENGHUBUNGKAN"}
        </span>
        <button
          className="display-audio-button"
          onClick={() => void toggleAudio()}
          aria-pressed={audioEnabled}
          title="Aktifkan atau matikan audio Display"
        >
          {audioEnabled ? "AUDIO AKTIF" : "AKTIFKAN AUDIO"}
        </button>
      </header>
      {game ? (
        <section className="display-body">
          <AnswerBoard state={game} display />
        </section>
      ) : (
        <section className="display-body connection-message">
          <div className="display-kicker">DISPLAY</div>
          <h1 className="display-question">Menunggu papan permainan.</h1>
          <p>{error || "Menghubungkan ke game…"}</p>
        </section>
      )}
      <div className="display-demo-note">
        {connection === "connected"
          ? "TERSINKRONISASI DENGAN HOST"
          : error || "MENCOBA MENYAMBUNG KEMBALI"}
      </div>
    </main>
  );
}
