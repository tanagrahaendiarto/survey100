"use client";

import { useCallback, useEffect, useState } from "react";
import type { GameAction, GameCommand } from "@/lib/game-command";
import type { GameView } from "@/lib/game-types";
import { browserClient } from "@/lib/supabase/browser";

type ApiError = { error?: string; code?: string };

export function useGame(host = false) {
  const endpoint = host ? "/api/host" : "/api/game";
  const [game, setGame] = useState<GameView | null>(null);
  const [authorized, setAuthorized] = useState(!host);
  const [connection, setConnection] = useState("connecting");
  const [realtime, setRealtime] = useState("connecting");
  const [error, setError] = useState("");

  const refresh = useCallback(async () => {
    try {
      const response = await fetch(endpoint, { cache: "no-store" });
      const body = (await response.json()) as GameView & ApiError;

      if (response.status === 401 && host) {
        setAuthorized(false);
        setError("");
        return false;
      }
      if (!response.ok) {
        setConnection("offline");
        setError(body.error ?? "Game tidak dapat dimuat.");
        return false;
      }

      setGame((current) =>
        !current || body.version >= current.version ? body : current,
      );
      setConnection("connected");
      setAuthorized(true);
      setError("");
      return true;
    } catch {
      setConnection("offline");
      setError("Backend tidak dapat dijangkau.");
      return false;
    }
  }, [endpoint, host]);

  useEffect(() => {
    const supabase = browserClient();
    if (!supabase) {
      setConnection("offline");
      setRealtime("offline");
      setError("Isi konfigurasi Supabase di .env.local, lalu restart server.");
      return;
    }

    void refresh();
    const channel = supabase
      .channel("top-survey-game")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "game_state" },
        () => void refresh(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "revealed_answers" },
        () => void refresh(),
      )
      .subscribe((status) => {
        if (status === "SUBSCRIBED") {
          void refresh().then((ok) =>
            setRealtime(ok ? "connected" : "reconnecting"),
          );
        } else if (["CHANNEL_ERROR", "TIMED_OUT", "CLOSED"].includes(status)) {
          setRealtime("reconnecting");
        }
      });

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [refresh]);

  useEffect(() => {
    if (!host || !authorized) return;

    const timer = window.setInterval(async () => {
      try {
        const response = await fetch("/api/host/session", { method: "PATCH" });
        if (response.status === 401) {
          setAuthorized(false);
          setError("Host lease kedaluwarsa. Login atau takeover kembali.");
        } else if (!response.ok) {
          setConnection("offline");
        } else {
          setConnection("connected");
        }
      } catch {
        setConnection("offline");
      }
    }, 15_000);

    return () => window.clearInterval(timer);
  }, [authorized, host]);

  const act = useCallback(
    async (
      action: GameAction,
      details: Pick<GameCommand, "questionId" | "answerId"> = {},
    ) => {
      if (!host || !game) return { ok: false, error: "Game belum siap." };

      try {
        const response = await fetch("/api/host", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            requestId: crypto.randomUUID(),
            expectedVersion: game.version,
            action,
            ...details,
          }),
        });
        const body = (await response.json()) as ApiError;
        if (!response.ok) {
          setError(body.error ?? "Aksi game gagal.");
          if (response.status === 401) setAuthorized(false);
          if (body.code === "STALE_STATE") await refresh();
          return { ok: false, error: body.error ?? "Aksi game gagal." };
        }

        const refreshed = await refresh();
        if (!refreshed) {
          return {
            ok: true,
            error: "Aksi tersimpan, tetapi state terbaru belum dimuat.",
          };
        }
        setError("");
        return { ok: true, error: "" };
      } catch {
        setConnection("offline");
        setError("Backend tidak dapat dijangkau. Aksi belum disimpan.");
        return { ok: false, error: "Backend tidak dapat dijangkau." };
      }
    },
    [game, host, refresh],
  );

  return {
    game,
    authorized,
    connection,
    realtime,
    error,
    refresh,
    act,
  };
}
