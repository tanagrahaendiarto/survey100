export type BroadcastSound = "correct" | "wrong-a" | "wrong-b";
export type GameAudioCue = BroadcastSound | "game-complete";

const audioFiles: Record<GameAudioCue, string> = {
  correct: "/audio/correct.mp3",
  "wrong-a": "/audio/wrong-a.mp3",
  "wrong-b": "/audio/wrong-b.mp3",
  "game-complete": "/audio/game-complete.mp3",
};

const decodedAudio = new WeakMap<
  AudioContext,
  Map<GameAudioCue, Promise<AudioBuffer>>
>();

export function getGameAudioContext(
  current: AudioContext | null,
): AudioContext | null {
  if (typeof window === "undefined" || typeof window.AudioContext === "undefined") {
    return null;
  }

  return current && current.state !== "closed" ? current : new AudioContext();
}

function loadAudio(context: AudioContext, cue: GameAudioCue) {
  let contextCache = decodedAudio.get(context);
  if (!contextCache) {
    contextCache = new Map();
    decodedAudio.set(context, contextCache);
  }

  const cached = contextCache.get(cue);
  if (cached) return cached;

  const request = fetch(audioFiles[cue])
    .then((response) => {
      if (!response.ok) throw new Error(`Audio ${cue} gagal dimuat.`);
      return response.arrayBuffer();
    })
    .then((data) => context.decodeAudioData(data))
    .catch((error: unknown) => {
      contextCache?.delete(cue);
      throw error;
    });

  contextCache.set(cue, request);
  return request;
}

export async function preloadGameAudio(
  context: AudioContext,
  cues: readonly GameAudioCue[],
) {
  await Promise.all(cues.map((cue) => loadAudio(context, cue).catch(() => undefined)));
}

export async function playGameAudio(
  context: AudioContext | null,
  cue: GameAudioCue,
) {
  if (!context || context.state === "closed") return false;

  try {
    if (context.state !== "running") await context.resume();
    const buffer = await loadAudio(context, cue);
    if (context.state !== "running") return false;

    const source = context.createBufferSource();
    const gain = context.createGain();
    source.buffer = buffer;
    gain.gain.value = cue === "game-complete" ? 0.65 : 0.9;
    source.connect(gain);
    gain.connect(context.destination);
    source.start();
    return true;
  } catch {
    return false;
  }
}
