import type { ReactNode } from "react";
import { ms, num, type Health, type PreflightCheck, type Percentiles, type Segment, type Snapshot } from "../lib/api";

export function Card({
  title,
  hint,
  right,
  children,
}: {
  title: string;
  hint?: string;
  right?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="card">
      <header>
        <h2>{title}</h2>
        {hint && <span className="hint">{hint}</span>}
        <div style={{ flex: 1 }} />
        {right}
      </header>
      {children}
    </section>
  );
}

export function Stat({ label, value, sub }: { label: string; value: ReactNode; sub?: ReactNode }) {
  return (
    <div className="stat">
      <span className="label">{label}</span>
      <span className="value">{value}</span>
      {sub != null && <span className="sub">{sub}</span>}
    </div>
  );
}

export function HealthPills({ health, onRefresh }: { health: Health | null; onRefresh: () => void }) {
  const item = (name: string, s?: { ok: boolean; error?: string; version?: string; brokers?: string }) => (
    <span className="pill" title={s?.error ?? s?.version ?? s?.brokers ?? "not checked"}>
      <span className={`dot ${s ? (s.ok ? "ok" : "bad") : ""}`} />
      {name}
    </span>
  );
  return (
    <div className="row">
      {item("Lago", health?.lago)}
      {item("RisingWave", health?.risingwave)}
      {item("ClickHouse", health?.clickhouse)}
      {item("Redpanda", health?.redpanda)}
      <button className="btn" onClick={onRefresh} style={{ padding: "3px 10px", fontSize: 12 }}>
        Test
      </button>
    </div>
  );
}

export function Checklist({ checks }: { checks: PreflightCheck[] }) {
  if (checks.length === 0) return null;
  return (
    <div className="checklist">
      {checks.map((c) => (
        <div className="item" key={c.name + c.detail}>
          <span className={`dot ${c.ok ? "ok" : "bad"}`} style={{ marginTop: 6 }} />
          <span className="name">{c.name}</span>
          <span className="detail">
            {c.detail}
            {!c.ok && c.gates.length > 0 && (
              <em style={{ color: "var(--text-muted)" }}> — blocks: {c.gates.join(", ")}</em>
            )}
          </span>
        </div>
      ))}
    </div>
  );
}

/**
 * Clock offsets are surfaced, never silently applied: a stamped segment spanning
 * two machines is only as trustworthy as the gap between their clocks.
 */
export function ClockPanel({ clocks }: { clocks: Snapshot["clocks"] }) {
  if (!clocks) return null;
  const rows: [string, number | null, string][] = [
    ["Lago API", clocks.lago, "from the HTTP Date header, ±1s by construction"],
    ["RisingWave", clocks.risingwave, "SELECT now() over pgwire, RTT-corrected"],
    ["ClickHouse", clocks.clickhouse, "SELECT now64(3) over HTTPS, RTT-corrected"],
  ];
  const worst = Math.max(...rows.map(([, v]) => (v == null ? 0 : Math.abs(v))));
  return (
    <>
      <table className="data">
        <thead>
          <tr>
            <th>Clock</th>
            <th>Offset vs this app</th>
            <th style={{ textAlign: "left" }}>How it was measured</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(([name, v, how]) => (
            <tr key={name}>
              <td>{name}</td>
              <td className="num">{v == null ? "—" : `${v >= 0 ? "+" : ""}${v} ms`}</td>
              <td style={{ textAlign: "left", color: "var(--text-secondary)", fontSize: 12 }}>{how}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p style={{ marginTop: 10, fontSize: 12, color: "var(--text-secondary)" }}>
        {worst > 250 ? (
          <>
            <b style={{ color: "var(--warning)" }}>⚠ offsets above 250 ms</b> — read the stamped breakdown with that in
            mind. The polled end-to-end numbers are unaffected: both of their endpoints are read from this app's clock.
          </>
        ) : (
          <>
            Offsets are small, so the stamped hop breakdown is meaningful. The polled end-to-end numbers never depend on
            these at all — both endpoints come from this app's clock.
          </>
        )}
      </p>
    </>
  );
}

export function PercentileTable({
  segments,
  stats,
  unavailable,
}: {
  segments: Segment[];
  stats: Record<string, Percentiles | undefined>;
  unavailable: string[];
}) {
  return (
    <div className="scroll">
      <table className="data">
        <thead>
          <tr>
            <th>Segment</th>
            <th>n</th>
            <th>min</th>
            <th>P50</th>
            <th>P95</th>
            <th>P99</th>
            <th>max</th>
            <th>mean</th>
          </tr>
        </thead>
        <tbody>
          {segments.map((seg) => {
            const p = stats[seg.key];
            const off = unavailable.includes(seg.key);
            return (
              <tr key={seg.key} className={p ? "" : "unavailable"}>
                <td title={`${seg.from} → ${seg.to}${seg.note ? `\n\n${seg.note}` : ""}`}>
                  {seg.label}
                  {seg.kind === "stamped" && (
                    <span style={{ color: "var(--text-muted)", fontSize: 11 }}> · clocks: {seg.clocks.join(" → ")}</span>
                  )}
                </td>
                {p ? (
                  <>
                    <td className="num">{num(p.count)}</td>
                    <td className="num" title={p.min < 0 ? "negative = clock skew between the two machines" : undefined}>
                      {p.min < 0 ? `⚠ ${ms(p.min, 1)}` : ms(p.min, 1)}
                    </td>
                    <td className="num" title={p.p50 < 0 ? "negative = clock skew between the two machines" : undefined}>
                      {p.p50 < 0 ? `⚠ ${ms(p.p50, 1)}` : ms(p.p50, 1)}
                    </td>
                    <td className="num">{ms(p.p95, 1)}</td>
                    <td className="num">{ms(p.p99, 1)}</td>
                    <td className="num">{ms(p.max, 1)}</td>
                    <td className="num">{ms(p.mean, 1)}</td>
                  </>
                ) : (
                  <td colSpan={7} style={{ textAlign: "left" }}>
                    {off ? "not measurable in this run" : "no samples yet"}
                  </td>
                )}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export function ErrorsPanel({ errors }: { errors: { msg: string; count: number }[] }) {
  if (errors.length === 0)
    return (
      <p style={{ color: "var(--text-secondary)", fontSize: 13 }}>
        <span className="dot ok" style={{ display: "inline-block", marginRight: 6 }} />
        No errors.
      </p>
    );
  return (
    <table className="data">
      <thead>
        <tr>
          <th>Error</th>
          <th>Count</th>
        </tr>
      </thead>
      <tbody>
        {errors.map((e) => (
          <tr key={e.msg}>
            <td style={{ fontFamily: "var(--mono)", fontSize: 12 }}>{e.msg}</td>
            <td className="num">{num(e.count)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export function LogPanel({ logs }: { logs: Snapshot["logs"] }) {
  if (!logs || logs.length === 0) return <p style={{ color: "var(--text-muted)", fontSize: 13 }}>Nothing logged yet.</p>;
  return (
    <div className="log">
      {[...logs].reverse().map((l, i) => (
        <div key={i} className={l.level === "warn" ? "l-warn" : l.level === "error" ? "l-error" : ""}>
          <span className="t">{new Date(l.t).toLocaleTimeString()} </span>
          {l.msg}
        </div>
      ))}
    </div>
  );
}

export function Banner({ kind, children }: { kind: "info" | "warn" | "bad"; children: ReactNode }) {
  const icon = kind === "bad" ? "✕" : kind === "warn" ? "⚠" : "i";
  return (
    <div className={`banner ${kind}`}>
      <span aria-hidden style={{ fontWeight: 700 }}>
        {icon}
      </span>
      <span>{children}</span>
    </div>
  );
}
