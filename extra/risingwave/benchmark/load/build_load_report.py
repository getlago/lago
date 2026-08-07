#!/usr/bin/env python3
"""Builds the load-test timeline report.
Usage: build_load_report.py <samples.jsonl> <producer_summary_json> <audit_json> <out.html>"""
import json
import sys

samples = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
producer = json.loads(sys.argv[2]) if sys.argv[2].startswith("{") else json.loads(open(sys.argv[2]).read().strip().splitlines()[-1])
audit = json.loads(sys.argv[3]) if sys.argv[3].startswith("{") else json.load(open(sys.argv[3]))

t0 = samples[0]["ts"]
for i, s in enumerate(samples):
    s["t"] = round((s["ts"] - t0) / 1000)
    prev = samples[i - 1] if i else s
    dt = max((s["ts"] - prev["ts"]) / 1000, 1)
    s["in_rate"] = round(max(s["raw_hwm"] - prev["raw_hwm"], 0) / dt)
    s["out_rate"] = round(max(s["shadow_hwm"] - prev["shadow_hwm"], 0) / dt)

raw0, shadow0 = samples[0]["raw_hwm"], samples[0]["shadow_hwm"]
offset = raw0 - shadow0
for s in samples:
    s["backlog"] = max((s["raw_hwm"] - s["shadow_hwm"]) - offset, 0)

peak_in = max(s["in_rate"] for s in samples)
peak_backlog = max(s["backlog"] for s in samples)
end_backlog = samples[-1]["backlog"]
peak_wlag = max(s["wallet_lag"] for s in samples)
end_wlag = samples[-1]["wallet_lag"]
e2e_vals = [s["e2e_avg_ms"] for s in samples if s["e2e_events"] > 50]
usage_vals = [s["usage_avg_ms"] for s in samples if s["usage_avg_ms"] > 0]
usage_max = max((s["usage_max_ms"] for s in samples), default=0)
peak_stale = max(s["proj_stale_s"] for s in samples)

verdict_ok = audit["lost"] == 0 and end_backlog < 100
verdict = "PASSED — zero loss, backlog drained" if verdict_ok else f"REVIEW — lost={audit['lost']}, end backlog={end_backlog}"

def fmt(ms):
    return f"{ms:.0f} ms" if ms < 1000 else f"{ms / 1000:.1f} s"

html = """<title>RisingWave path — load test report</title>
<style>
  :root { color-scheme: light;
    --page:#f9f9f7; --surface:#fcfcfb; --ink:#0b0b0b; --ink-2:#52514e; --muted:#898781;
    --grid:#e1e0d9; --axis:#c3c2b7; --ring:rgba(11,11,11,0.10);
    --s1:#2a78d6; --s2:#eb6834; --s3:#1baf7a; --s4:#eda100; --good:#006300; --bad:#d03b3b; }
  @media (prefers-color-scheme: dark) { :root:where(:not([data-theme="light"])) { color-scheme: dark;
    --page:#0d0d0d; --surface:#1a1a19; --ink:#fff; --ink-2:#c3c2b7; --muted:#898781;
    --grid:#2c2c2a; --axis:#383835; --ring:rgba(255,255,255,0.10);
    --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --good:#0ca30c; --bad:#d03b3b; } }
  :root[data-theme="dark"] { color-scheme: dark;
    --page:#0d0d0d; --surface:#1a1a19; --ink:#fff; --ink-2:#c3c2b7; --muted:#898781;
    --grid:#2c2c2a; --axis:#383835; --ring:rgba(255,255,255,0.10);
    --s1:#3987e5; --s2:#d95926; --s3:#199e70; --s4:#c98500; --good:#0ca30c; --bad:#d03b3b; }
  * { box-sizing:border-box; } body { margin:0; background:var(--page); color:var(--ink);
    font:15px/1.55 system-ui,-apple-system,"Segoe UI",sans-serif; }
  main { max-width:1060px; margin:0 auto; padding:44px 28px 80px; }
  .eyebrow { font-size:12px; letter-spacing:0.08em; text-transform:uppercase; color:var(--muted); font-weight:600; }
  h1 { font-size:28px; line-height:1.2; margin:8px 0 6px; text-wrap:balance; }
  .sub { color:var(--ink-2); max-width:70ch; margin:0 0 30px; }
  h2 { font-size:18px; margin:40px 0 4px; }
  .note { color:var(--ink-2); font-size:13px; max-width:78ch; margin:0 0 12px; }
  .kpis { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:12px; }
  .tile { background:var(--surface); border:1px solid var(--ring); border-radius:8px; padding:14px 16px; }
  .tile .l { font-size:12px; color:var(--muted); font-weight:600; }
  .tile .v { font-size:27px; font-weight:700; margin-top:3px; }
  .tile .d { font-size:12.5px; color:var(--ink-2); margin-top:3px; }
  .accent { color:var(--s1); } .good { color:var(--good); } .bad { color:var(--bad); }
  .card { background:var(--surface); border:1px solid var(--ring); border-radius:8px; padding:18px 20px; margin-top:12px; }
  .card h3 { margin:0 0 2px; font-size:14.5px; }
  .card .cnote { font-size:12.5px; color:var(--muted); margin-bottom:10px; }
  .legend { display:flex; flex-wrap:wrap; gap:14px; font-size:12.5px; color:var(--ink-2); margin-bottom:8px; }
  .legend span::before { content:""; display:inline-block; width:10px; height:3px; border-radius:2px; margin-right:6px; vertical-align:3px; }
  .chartwrap { overflow-x:auto; }
  svg text { font:11.5px system-ui,sans-serif; fill:var(--muted); }
  .grid2 { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
  @media (max-width:860px) { .grid2 { grid-template-columns:1fr; } }
  .verdict { display:inline-block; padding:6px 14px; border-radius:999px; font-weight:650; font-size:14px; }
  .verdict.ok { background:color-mix(in srgb, var(--good) 12%, transparent); color:var(--good); }
  .verdict.warn { background:color-mix(in srgb, var(--bad) 12%, transparent); color:var(--bad); }
  table { border-collapse:collapse; font-size:13.5px; font-variant-numeric:tabular-nums; }
  td, th { padding:6px 18px 6px 0; text-align:left; border-bottom:1px solid var(--grid); }
  th { color:var(--muted); font-size:12px; }
  .tip { position:fixed; pointer-events:none; background:var(--ink); color:var(--page); padding:6px 10px;
    border-radius:6px; font-size:12px; opacity:0; z-index:10; white-space:nowrap; }
  footer { margin-top:48px; font-size:12.5px; color:var(--muted); border-top:1px solid var(--grid); padding-top:14px; max-width:80ch; }
</style>
<main>
  <div class="eyebrow">Lago billing platform · engineering · load test</div>
  <h1>RisingWave path under load: __RATE__ events/s × __DUR__</h1>
  <p class="sub">__SENT__ events across 200 subscriptions (30% count, 40% charge-filtered, 30% group-keyed;
  20 customers with active wallets), produced at a controlled rate into the full pipeline —
  enrichment, dedup, period-keyed usage, Postgres projections, hourly ClickHouse rollups, and
  event-driven wallet refresh — sampled every 5 s. Dev stack (single-node RisingWave, WSL2).</p>

  <div class="kpis">
    <div class="tile"><div class="l">Delivered</div><div class="v">__SENT__</div><div class="d">events · avg __AVG_RATE__/s sustained</div></div>
    <div class="tile"><div class="l">Correctness</div><div class="v __VERDICT_CLS__" style="font-size:19px; padding-top:6px">__VERDICT__</div><div class="d">produced vs aggregated, post-run audit</div></div>
    <div class="tile"><div class="l">Enrichment latency</div><div class="v accent">__E2E_AVG__</div><div class="d">avg during run · max __E2E_MAX__</div></div>
    <div class="tile"><div class="l">Usage-row latency</div><div class="v accent">__U_AVG__</div><div class="d">avg during run · max __U_MAX__</div></div>
    <div class="tile"><div class="l">Peak enrich backlog</div><div class="v">__PEAK_BACKLOG__</div><div class="d">events queued · __END_BACKLOG__ at end</div></div>
    <div class="tile"><div class="l">Wallet consumer lag</div><div class="v">__PEAK_WLAG__</div><div class="d">peak messages · __END_WLAG__ at end</div></div>
  </div>

  <h2>Timeline</h2>
  <p class="note">Hover any chart for exact values. All series share the run clock (elapsed minutes).</p>

  <div class="grid2">
    <div class="card"><h3>Throughput (events/s)</h3><div class="cnote">in = produced to Kafka · out = enriched by RisingWave</div>
      <div class="legend"><span style="--c:var(--s1)"></span></div>
      <div class="chartwrap"><svg class="ch" data-series="in_rate:in:--s1,out_rate:out:--s2" width="480" height="200"></svg></div></div>
    <div class="card"><h3>Backlog &amp; consumer lag (messages)</h3><div class="cnote">enrich backlog = produced − enriched · wallet lag = trigger topic behind</div>
      <div class="chartwrap"><svg class="ch" data-series="backlog:enrich backlog:--s1,wallet_lag:wallet lag:--s2" width="480" height="200"></svg></div></div>
    <div class="card"><h3>Latency (ms, per-minute averages)</h3><div class="cnote">from the pipeline’s own latency MVs (broker-timestamp based)</div>
      <div class="chartwrap"><svg class="ch" data-series="e2e_avg_ms:enrich e2e:--s1,usage_avg_ms:usage row:--s2" width="480" height="200"></svg></div></div>
    <div class="card"><h3>Projection staleness (s) &amp; wallet refreshes /5s</h3><div class="cnote">staleness = now − newest usage write visible to the API</div>
      <div class="chartwrap"><svg class="ch" data-series="proj_stale_s:staleness s:--s1,wallets_synced:wallets synced:--s2" width="480" height="200"></svg></div></div>
  </div>

  <div class="card"><h3>Container CPU (%)</h3><div class="cnote">docker stats, sampled — RisingWave is the working core of the pipeline; &gt;100% = more than one core</div>
    <div class="chartwrap"><svg class="ch" data-series="cpu_rw:risingwave:--s1,cpu_consumer:karafka consumer:--s2,cpu_redpanda:redpanda:--s3,cpu_pg:postgres:--s4" width="1000" height="220"></svg></div></div>

  <h2>Correctness audit</h2>
  <div class="card">
    <p class="note" style="margin-bottom:10px"><span class="verdict __VERDICT_CLS2__">__VERDICT_LONG__</span></p>
    <table>
      <tr><th>Check</th><th>Expected</th><th>Observed</th></tr>
      <tr><td>Events produced</td><td>—</td><td>__SENT__</td></tr>
      <tr><td>Events aggregated into usage (Δ events_count)</td><td>__SENT__</td><td>__COUNTED__</td></tr>
      <tr><td>Lost / duplicated</td><td>0</td><td>__LOST__</td></tr>
      <tr><td>Usage rows without a billing period</td><td>0</td><td>__ORPHANS__</td></tr>
      <tr><td>Projection rows (subscription × charge × filter × group)</td><td>—</td><td>__PROJ_ROWS__</td></tr>
    </table>
  </div>

  <footer>Method: rate-controlled producer (10 ticks/s) into <code>events-raw</code>; backlog from Kafka
  high-watermarks (enriched output is 1:1 with events in this mix); latency from the pipeline’s
  self-measuring MVs (Kafka broker timestamps, per-minute windows); consumer lag via
  <code>rpk group describe</code>; audit compares the producer’s count against the delta of
  <code>SUM(events_count)</code> in <code>usage_realtime_projections</code> — dedup and exactly-once
  attribution are load-bearing here. Single-node RisingWave (<code>barrier_interval_ms=250</code>)
  on a shared dev machine; treat absolute CPU as indicative, shapes as real.</footer>
</main>
<div class="tip" id="tip"></div>
<script>
const S = __SAMPLES__;
S.forEach(s => { s.cpu_rw = s.cpu["lago_risingwave_dev"] || 0; s.cpu_consumer = s.cpu["lago_api_events_consumer_dev"] || 0;
  s.cpu_redpanda = s.cpu["lago_redpanda_dev"] || 0; s.cpu_pg = s.cpu["lago_db_dev"] || 0; });
const tip = document.getElementById("tip");
const css = v => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
function draw() {
document.querySelectorAll("svg.ch").forEach(svg => {
  svg.innerHTML = "";
  const spec = svg.dataset.series.split(",").map(x => x.split(":"));
  const W = +svg.getAttribute("width"), H = +svg.getAttribute("height"), L = 46, R = 8, T = 10, B = 24;
  const NS = "http://www.w3.org/2000/svg";
  const el = (t, a, parent) => { const e = document.createElementNS(NS, t); for (const k in a) e.setAttribute(k, a[k]); (parent || svg).appendChild(e); return e; };
  const xs = S.map(s => s.t), xmax = Math.max(...xs);
  let ymax = 0; spec.forEach(([k]) => S.forEach(s => { if (s[k] > ymax) ymax = s[k]; }));
  ymax = ymax || 1; ymax *= 1.12;
  const X = t => L + t / xmax * (W - L - R), Y = v => T + (1 - v / ymax) * (H - T - B);
  for (let g = 0; g <= 3; g++) { const v = ymax * g / 3;
    el("line", { x1: L, x2: W - R, y1: Y(v), y2: Y(v), stroke: css("--grid") });
    const t = el("text", { x: L - 6, y: Y(v) + 4, "text-anchor": "end" }); t.textContent = v >= 1000 ? (v / 1000).toFixed(1) + "k" : Math.round(v); }
  for (let m = 0; m <= Math.floor(xmax / 60); m++) { const t = el("text", { x: X(m * 60), y: H - 6, "text-anchor": "middle" }); t.textContent = m + "m"; }
  const lgd = svg.closest(".card").querySelector(".legend");
  if (lgd) lgd.innerHTML = "";
  spec.forEach(([k, label, cvar]) => {
    const pts = S.map(s => X(s.t) + "," + Y(s[k])).join(" ");
    el("polyline", { points: pts, fill: "none", stroke: css(cvar), "stroke-width": 2, "stroke-linejoin": "round" });
    if (lgd) { const sp = document.createElement("span"); sp.textContent = label; sp.style.setProperty("--c", css(cvar));
      sp.setAttribute("style", "--c:" + css(cvar)); lgd.appendChild(sp);
      const st = document.createElement("style"); }
  });
  const hover = el("rect", { x: L, y: T, width: W - L - R, height: H - T - B, fill: "transparent" });
  const cross = el("line", { x1: 0, x2: 0, y1: T, y2: H - B, stroke: css("--axis"), "stroke-width": 1, opacity: 0 });
  hover.addEventListener("mousemove", ev => {
    const r = svg.getBoundingClientRect();
    const t = (ev.clientX - r.left - L) / (W - L - R) * xmax;
    let best = S[0]; S.forEach(s => { if (Math.abs(s.t - t) < Math.abs(best.t - t)) best = s; });
    cross.setAttribute("x1", X(best.t)); cross.setAttribute("x2", X(best.t)); cross.setAttribute("opacity", 1);
    tip.innerHTML = "t+" + Math.floor(best.t / 60) + "m" + (best.t % 60) + "s · " + spec.map(([k, label]) => label + ": " + best[k]).join(" · ");
    tip.style.opacity = 1; tip.style.left = Math.min(ev.clientX + 12, innerWidth - 320) + "px"; tip.style.top = (ev.clientY - 34) + "px";
  });
  hover.addEventListener("mouseleave", () => { tip.style.opacity = 0; cross.setAttribute("opacity", 0); });
});
// legend swatch colors
document.querySelectorAll(".legend span").forEach(sp => { sp.style.cssText += ";--x:1"; });
}
const style = document.createElement("style");
style.textContent = ".legend span::before{background:var(--c)!important}";
document.head.appendChild(style);
draw();
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", draw);
</script>
"""

reps = {
    "__RATE__": str(producer.get("target_rate", round(producer["avg_rate"]))),
    "__DUR__": f"{round(producer['elapsed_s'] / 60)} min",
    "__SENT__": f"{producer['sent']:,}",
    "__AVG_RATE__": str(round(producer["avg_rate"])),
    "__VERDICT_CLS__": "good" if verdict_ok else "bad",
    "__VERDICT_CLS2__": "ok" if verdict_ok else "warn",
    "__VERDICT__": "PASSED" if verdict_ok else "REVIEW",
    "__VERDICT_LONG__": verdict,
    "__E2E_AVG__": fmt(sum(e2e_vals) / len(e2e_vals)) if e2e_vals else "—",
    "__E2E_MAX__": fmt(max((s["e2e_max_ms"] for s in samples), default=0)),
    "__U_AVG__": fmt(sum(usage_vals) / len(usage_vals)) if usage_vals else "—",
    "__U_MAX__": fmt(usage_max),
    "__PEAK_BACKLOG__": f"{peak_backlog:,}",
    "__END_BACKLOG__": f"{end_backlog:,}",
    "__PEAK_WLAG__": f"{peak_wlag:,}",
    "__END_WLAG__": f"{end_wlag:,}",
    "__COUNTED__": f"{audit['counted']:,}",
    "__LOST__": str(audit["lost"]),
    "__ORPHANS__": str(audit["orphans"]),
    "__PROJ_ROWS__": f"{samples[-1]['proj_rows']:,}",
    "__SAMPLES__": json.dumps(samples),
}
for k, v in reps.items():
    html = html.replace(k, v)

open(sys.argv[4], "w").write(html)
print("load report written to", sys.argv[4])
