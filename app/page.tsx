import Link from "next/link";

export default function HomePage() {
  return (
    <main className="landing">
      <div className="landing-top">
        <span className="brand-mark">TS</span>
        <span>TOP SURVEY</span>
        <span className="event-tag">
          UNPAD <i>×</i> IPB
        </span>
      </div>
      <section className="hero">
        <div className="eyebrow">
          <span className="live-dot" /> PERMAINAN SURVEI INTERAKTIF
        </div>
        <h1>
          Seberapa banyak
          <br />
          <em>kamu tahu?</em>
        </h1>
        <p className="hero-copy">
          Dua tim. Lima jawaban tersembunyi. Satu papan permainan—siap untuk
          malam yang seru.
        </p>
        <div className="entry-actions">
          <Link className="button button-primary" href="/host">
            Buka Host <span>↗</span>
          </Link>
          <Link className="button button-quiet" href="/display" target="_blank">
            Buka Display <span>↗</span>
          </Link>
        </div>
        <div className="hero-meta">
          <span>SOAL DINAMIS</span>
          <span>02 TIM</span>
          <span>05 JAWABAN PER BABAK</span>
        </div>
      </section>
      <div className="landing-foot">
        <span>STUDI BANDING 2026</span>
        <span>
          DIRANCANG UNTUK LAYAR PANGGUNG <b>↗</b>
        </span>
      </div>
    </main>
  );
}
