#!/usr/bin/env python3
"""Builds the before/after latency report page from full_path_benchmark
results. Usage: build_report.py <old.jsonl> <new.jsonl> <out.html>"""
import json
import statistics
import sys
from datetime import date

old_rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
new_rows = [json.loads(l) for l in open(sys.argv[2]) if l.strip()]

STEPS = ["ingestion_ms", "enriched_ms", "usage_ms", "wallet_ms"]
STEP_LABELS = {
    "ingestion_ms": "Ingested (event on Kafka)",
    "enriched_ms": "Enriched (billing attribution done)",
    "usage_ms": "Usage readable (serving store updated)",
    "wallet_ms": "Wallet refreshed (ongoing balance)",
}


def stats(rows, step):
    vals = sorted(r[step] for r in rows if r.get(step) is not None)
    if not vals:
        return None
    return {
        "median": statistics.median(vals),
        "min": vals[0],
        "max": vals[-1],
        "n": len(vals),
        "timeouts": sum(1 for r in rows if r.get(step) is None),
        "samples": vals,
    }


data = {
    "old": {s: stats(old_rows, s) for s in STEPS},
    "new": {s: stats(new_rows, s) for s in STEPS},
}


def fmt_ms(ms):
    if ms is None:
        return "—"
    if ms < 1000:
        return f"{ms:.0f} ms"
    if ms < 60_000:
        return f"{ms / 1000:.1f} s"
    return f"{ms / 60_000:.1f} min"


old_wallet = data["old"]["wallet_ms"]["median"]
new_wallet = data["new"]["wallet_ms"]["median"]
old_usage = data["old"]["usage_ms"]["median"]
new_usage = data["new"]["usage_ms"]["median"]
speedup_wallet = old_wallet / new_wallet
speedup_usage = old_usage / new_usage

table_rows = []
for path, rows in (("legacy", old_rows), ("risingwave", new_rows)):
    for r in rows:
        cells = "".join(
            f"<td>{fmt_ms(r[s]) if r.get(s) is not None else 'timeout'}</td>" for s in STEPS
        )
        table_rows.append(
            f"<tr><td>{path}</td><td class='tx'>{r['tx']}</td>{cells}</tr>"
        )
table_html = "\n".join(table_rows)

html = """<title>Realtime usage & wallets — pipeline latency, before / after</title>
<style>
  :root {
    color-scheme: light;
    --page: #f9f9f7; --surface: #fcfcfb;
    --ink: #0b0b0b; --ink-2: #52514e; --muted: #898781;
    --grid: #e1e0d9; --axis: #c3c2b7; --ring: rgba(11,11,11,0.10);
    --new: #2a78d6; --old: #898781; --good: #006300;
  }
  @media (prefers-color-scheme: dark) {
    :root:where(:not([data-theme="light"])) {
      color-scheme: dark;
      --page: #0d0d0d; --surface: #1a1a19;
      --ink: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
      --grid: #2c2c2a; --axis: #383835; --ring: rgba(255,255,255,0.10);
      --new: #3987e5; --old: #898781; --good: #0ca30c;
    }
  }
  :root[data-theme="dark"] {
    color-scheme: dark;
    --page: #0d0d0d; --surface: #1a1a19;
    --ink: #ffffff; --ink-2: #c3c2b7; --muted: #898781;
    --grid: #2c2c2a; --axis: #383835; --ring: rgba(255,255,255,0.10);
    --new: #3987e5; --old: #898781; --good: #0ca30c;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--page); color: var(--ink);
    font: 15px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  main { max-width: 1040px; margin: 0 auto; padding: 48px 28px 80px; }
  .eyebrow { font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); font-weight: 600; }
  h1 { font-size: 30px; line-height: 1.2; margin: 8px 0 6px; text-wrap: balance; font-weight: 700; }
  .sub { color: var(--ink-2); max-width: 68ch; margin: 0 0 34px; }
  h2 { font-size: 19px; margin: 46px 0 6px; }
  .note { color: var(--ink-2); font-size: 13.5px; max-width: 76ch; margin: 0 0 16px; }
  .kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
  .tile { background: var(--surface); border: 1px solid var(--ring); border-radius: 8px; padding: 16px 18px; }
  .tile .l { font-size: 12.5px; color: var(--muted); font-weight: 600; }
  .tile .v { font-size: 34px; font-weight: 700; line-height: 1.15; margin-top: 4px; }
  .tile .d { font-size: 13px; color: var(--ink-2); margin-top: 4px; }
  .tile .v.accent { color: var(--new); }
  .tile .v.good { color: var(--good); }
  .card { background: var(--surface); border: 1px solid var(--ring); border-radius: 8px; padding: 20px 22px; margin-top: 14px; }
  .legend { display: flex; gap: 18px; font-size: 13px; color: var(--ink-2); margin: 2px 0 14px; }
  .legend span::before { content: ""; display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 7px; vertical-align: -1px; }
  .legend .n::before { background: var(--new); }
  .legend .o::before { background: var(--old); }
  .chartwrap { overflow-x: auto; }
  svg text { font: 12.5px system-ui, -apple-system, "Segoe UI", sans-serif; fill: var(--ink-2); }
  svg .val { font-weight: 650; fill: var(--ink); }
  svg .tick { fill: var(--muted); font-size: 11.5px; }
  .flow { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: 14px; }
  @media (max-width: 760px) { .flow { grid-template-columns: 1fr; } }
  .chain { background: var(--surface); border: 1px solid var(--ring); border-radius: 8px; padding: 16px 18px; }
  .chain h3 { margin: 0 0 2px; font-size: 14.5px; }
  .chain .t { font-size: 12px; color: var(--muted); margin-bottom: 12px; }
  .chain ol { margin: 0; padding: 0; list-style: none; font-size: 13.5px; }
  .chain li { padding: 7px 0 7px 14px; border-left: 2px solid var(--axis); position: relative; color: var(--ink-2); }
  .chain li b { color: var(--ink); font-weight: 600; }
  .chain li em { font-style: normal; color: var(--muted); font-size: 12px; }
  .chain.new li { border-left-color: var(--new); }
  table { border-collapse: collapse; width: 100%; font-size: 13px; font-variant-numeric: tabular-nums; }
  th, td { text-align: left; padding: 7px 12px 7px 0; border-bottom: 1px solid var(--grid); }
  th { color: var(--muted); font-weight: 600; font-size: 12px; }
  td.tx { color: var(--muted); font-family: ui-monospace, monospace; font-size: 11.5px; }
  .tip { position: fixed; pointer-events: none; background: var(--ink); color: var(--page); padding: 6px 10px; border-radius: 6px; font-size: 12.5px; opacity: 0; transition: opacity 0.12s; z-index: 10; white-space: nowrap; }
  footer { margin-top: 52px; font-size: 12.5px; color: var(--muted); border-top: 1px solid var(--grid); padding-top: 16px; max-width: 78ch; }
</style>
<main>
  <div class="eyebrow">Lago billing platform · engineering</div>
  <h1>Realtime usage &amp; wallets: pipeline latency, before / after</h1>
  <p class="sub">One usage event was sent through both pipelines and timed at every stage,
  from Kafka broker timestamps and serving-store polling — the legacy path
  (Go events-processor → ClickHouse → refresh flag → clock sweep) against the new
  RisingWave path (streaming enrichment → incremental usage → event-driven wallet refresh).
  Measured on the dev stack, __DATE__.</p>

  <div class="kpis">
    <div class="tile"><div class="l">Event → wallet refreshed · before</div><div class="v">__OLD_WALLET__</div><div class="d">median · flag + clock sweep (__SWEEP__ interval)</div></div>
    <div class="tile"><div class="l">Event → wallet refreshed · after</div><div class="v accent">__NEW_WALLET__</div><div class="d">median · event-driven, no clock</div></div>
    <div class="tile"><div class="l">Wallet freshness gain</div><div class="v good">__SPEEDUP_WALLET__× faster</div><div class="d">and deterministic — no interval lottery</div></div>
    <div class="tile"><div class="l">Usage readable · before → after</div><div class="v"><span style="color:var(--old)">__OLD_USAGE__</span> → <span class="accent" style="color:var(--new)">__NEW_USAGE__</span></div><div class="d">median · __SPEEDUP_USAGE__× faster, O(1) read</div></div>
  </div>

  <h2>Latency by stage</h2>
  <p class="note">Each dot is the median for that stage; log scale — every gridline is 10× the
  previous. Hover any dot for min / median / max. Ingestion and enrichment were already fast;
  the new path wins where money is computed: usage and wallets.</p>
  <div class="card">
    <div class="legend"><span class="n">RisingWave path</span><span class="o">Legacy path</span></div>
    <div class="chartwrap"><svg id="dumbbell" width="960" height="300" role="img" aria-label="Median latency per stage, legacy vs RisingWave, log scale"></svg></div>
  </div>

  <h2>What each path does</h2>
  <div class="flow">
    <div class="chain">
      <h3>Legacy path</h3><div class="t">per-request recomputation, clock-driven refresh</div>
      <ol>
        <li><b>Kafka</b> events-raw <em>· shared</em></li>
        <li><b>Go events-processor</b> enriches → Kafka → ClickHouse ingests</li>
        <li><b>Usage on request:</b> ClickHouse aggregation query per charge + Redis cache</li>
        <li><b>Wallet:</b> Redis flag → clock consumes flags (10s) → refresh sweep every <b>__SWEEP__</b></li>
      </ol>
    </div>
    <div class="chain new">
      <h3>RisingWave path</h3><div class="t">incremental computation, event-driven refresh</div>
      <ol>
        <li><b>Kafka</b> events-raw <em>· shared</em></li>
        <li><b>RisingWave</b> enriches with temporal joins, dedups, corrects reprocesses</li>
        <li><b>Usage maintained continuously:</b> period-keyed rows upserted into Postgres, O(1) read</li>
        <li><b>Wallet:</b> per-event trigger topic (partitioned by customer) → consumer refreshes inline</li>
      </ol>
    </div>
  </div>

  <h2>Every sample</h2>
  <p class="note">All measurements, no filtering. "timeout" = not observed within the probe window
  (legacy wallet probes bound at 7 min). The legacy wallet spread is structural: latency depends on
  where in the __SWEEP__ sweep interval the event lands (production default: 5 min).</p>
  <div class="card chartwrap">
    <table>
      <thead><tr><th>Path</th><th>Event</th><th>Ingested</th><th>Enriched</th><th>Usage readable</th><th>Wallet refreshed</th></tr></thead>
      <tbody>__TABLE__</tbody>
    </table>
  </div>

  <footer>
    Method: events produced to <code>events-raw</code> with stamped ingestion time; “ingested” and
    “enriched” from Kafka broker timestamps (legacy: <code>events_enriched_expanded</code> by the Go
    processor; new: RisingWave’s shadow output); “usage readable” when the path’s serving store
    reflects the event (ClickHouse row queryable vs <code>usage_realtime_projections</code> updated);
    “wallet refreshed” when <code>wallets.ongoing_usage_balance_cents</code> changes. Dev stack, zero
    background load — a best case for the legacy path, whose production latency grows with consumer
    lag and per-request query cost, while the new path’s stages are volume-independent.
    RisingWave <code>barrier_interval_ms=250</code>. Both pipelines consumed the same events.
  </footer>
</main>
<div class="tip" id="tip"></div>
<script>
const DATA = __DATA__;
const STEPS = [
  ["ingestion_ms", "Ingested"],
  ["enriched_ms", "Enriched"],
  ["usage_ms", "Usage readable"],
  ["wallet_ms", "Wallet refreshed"],
];
const fmt = (ms) => ms == null ? "—" : ms < 1000 ? Math.round(ms) + " ms" : ms < 60000 ? (ms / 1000).toFixed(1) + " s" : (ms / 60000).toFixed(1) + " min";
const svg = document.getElementById("dumbbell");
const tip = document.getElementById("tip");
const css = (v) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
function draw() {
  svg.innerHTML = "";
  const W = 960, H = 300, L = 200, R = 40, T = 24, B = 40;
  const lo = Math.log10(10), hi = Math.log10(600000);
  const x = (ms) => L + (Math.log10(Math.max(ms, 10)) - lo) / (hi - lo) * (W - L - R);
  const rowH = (H - T - B) / STEPS.length;
  const NS = "http://www.w3.org/2000/svg";
  const el = (t, a) => { const e = document.createElementNS(NS, t); for (const k in a) e.setAttribute(k, a[k]); svg.appendChild(e); return e; };
  [10, 100, 1000, 10000, 60000, 300000].forEach((ms) => {
    el("line", { x1: x(ms), x2: x(ms), y1: T, y2: H - B, stroke: css("--grid"), "stroke-width": 1 });
    const t = el("text", { x: x(ms), y: H - B + 18, "text-anchor": "middle", class: "tick" });
    t.textContent = ms < 1000 ? ms + " ms" : ms < 60000 ? ms / 1000 + " s" : ms / 60000 + " min";
  });
  STEPS.forEach(([k, label], i) => {
    const y = T + rowH * i + rowH / 2;
    const o = DATA.old[k], n = DATA.new[k];
    const lt = el("text", { x: 0, y: y + 4 });
    lt.textContent = label;
    if (o && n) el("line", { x1: x(n.median), x2: x(o.median), y1: y, y2: y, stroke: css("--axis"), "stroke-width": 2 });
    [[o, "--old", "old"], [n, "--new", "new"]].forEach(([s, cvar, which]) => {
      if (!s) return;
      // min–max span
      el("line", { x1: x(s.min), x2: x(s.max), y1: y, y2: y, stroke: css(cvar), "stroke-width": 3, opacity: 0.35, "stroke-linecap": "round" });
      const c = el("circle", { cx: x(s.median), cy: y, r: 7, fill: css(cvar), stroke: css("--surface"), "stroke-width": 2 });
      const hit = el("circle", { cx: x(s.median), cy: y, r: 14, fill: "transparent" });
      const show = (ev) => {
        tip.textContent = (which === "new" ? "RisingWave" : "Legacy") + " · " + label.toLowerCase() + ": median " + fmt(s.median) + " (min " + fmt(s.min) + ", max " + fmt(s.max) + ", n=" + s.n + (s.timeouts ? ", " + s.timeouts + " timeout" : "") + ")";
        tip.style.opacity = 1; tip.style.left = (ev.clientX + 14) + "px"; tip.style.top = (ev.clientY - 10) + "px";
      };
      hit.addEventListener("mousemove", show);
      hit.addEventListener("mouseleave", () => tip.style.opacity = 0);
      const v = el("text", { x: x(s.median), y: y - 14, "text-anchor": "middle", class: "val" });
      v.textContent = fmt(s.median);
    });
  });
  el("line", { x1: L, x2: W - R, y1: H - B, y2: H - B, stroke: css("--axis"), "stroke-width": 1 });
}
draw();
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", draw);
</script>
"""

html = (
    html.replace("__DATE__", date.today().strftime("%B %d, %Y"))
    .replace("__OLD_WALLET__", fmt_ms(old_wallet))
    .replace("__NEW_WALLET__", fmt_ms(new_wallet))
    .replace("__SPEEDUP_WALLET__", f"{speedup_wallet:.0f}")
    .replace("__OLD_USAGE__", fmt_ms(old_usage))
    .replace("__NEW_USAGE__", fmt_ms(new_usage))
    .replace("__SPEEDUP_USAGE__", f"{speedup_usage:.0f}")
    .replace("__TABLE__", table_html)
    .replace("__SWEEP__", sys.argv[4] if len(sys.argv) > 4 else "5 min")
    .replace("__DATA__", json.dumps(data))
)

open(sys.argv[3], "w").write(html)
print(f"report written to {sys.argv[3]}")
