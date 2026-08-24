import { useEffect, useState } from "react";
import { api, duration, ms, num, type Percentiles, type Segment, type Snapshot } from "../lib/api";
import { Card, ClockPanel, ErrorsPanel, PercentileTable } from "../components/panels";
import { PercentileBars, type PercentileRow } from "../components/charts";

type RunRow = {
  id: string;
  phase: string;
  startedAt: number;
  endedAt: number;
  sent: number;
  rateEps: number;
  stats: Record<string, Percentiles | undefined>;
};

const HEADLINE = "ch_rw_expanded_visible";

export function History({ segments }: { segments: Segment[] }) {
  const [runs, setRuns] = useState<RunRow[] | null>(null);
  const [open, setOpen] = useState<Snapshot | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const load = () => {
    api
      .runs()
      .then((r) => setRuns(r.runs))
      .catch((e) => setErr((e as Error).message));
  };

  useEffect(load, []);

  const openRun = async (id: string) => {
    try {
      setOpen(await api.run(id));
    } catch (e) {
      setErr((e as Error).message);
    }
  };

  const rows: PercentileRow[] = open
    ? segments
        .filter((s) => s.kind === "polled" && open.stats?.[s.key])
        .map((s) => {
          const p = open.stats![s.key]!;
          return { key: s.key, label: s.label, p50: p.p50, p95: p.p95, p99: p.p99, count: p.count };
        })
    : [];

  return (
    <>
      <Card
        title="Past runs"
        hint="persisted under loadtest/runs/<id>/ as summary.json + events.jsonl"
        right={
          <button className="btn" onClick={load}>
            Refresh
          </button>
        }
      >
        {err && <p style={{ color: "var(--critical)" }}>{err}</p>}
        {!runs && <p style={{ color: "var(--text-muted)" }}>Loading…</p>}
        {runs && runs.length === 0 && <p style={{ color: "var(--text-muted)" }}>No runs yet.</p>}
        {runs && runs.length > 0 && (
          <div className="scroll">
            <table className="data">
              <thead>
                <tr>
                  <th>Run</th>
                  <th>Started</th>
                  <th>Duration</th>
                  <th>Rate</th>
                  <th>Sent</th>
                  <th>Phase</th>
                  <th>P50 → CH expanded</th>
                  <th>P99 → CH expanded</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {runs.map((r) => (
                  <tr key={r.id}>
                    <td className="mono">{r.id}</td>
                    <td>{new Date(r.startedAt).toLocaleString()}</td>
                    <td className="num">{duration(r.endedAt - r.startedAt)}</td>
                    <td className="num">{num(r.rateEps)}/s</td>
                    <td className="num">{num(r.sent)}</td>
                    <td>{r.phase}</td>
                    <td className="num">{ms(r.stats?.[HEADLINE]?.p50)}</td>
                    <td className="num">{ms(r.stats?.[HEADLINE]?.p99)}</td>
                    <td>
                      <button className="btn" style={{ padding: "3px 10px", fontSize: 12 }} onClick={() => openRun(r.id)}>
                        Open
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {open && (
        <>
          <Card
            title={`Run ${open.id}`}
            hint={`${num(open.counters?.accepted)} accepted at ${num(open.spec?.rateEps)}/s · ${duration(open.elapsedMs)}`}
            right={
              <button className="btn" onClick={() => setOpen(null)}>
                Close
              </button>
            }
          >
            <PercentileBars rows={rows} />
          </Card>
          <Card title="All segments">
            <PercentileTable segments={segments} stats={open.stats ?? {}} unavailable={open.unavailable ?? []} />
          </Card>
          <div className="grid cols-2">
            <Card title="Clock offsets">
              <ClockPanel clocks={open.clocks} />
            </Card>
            <Card title="Errors">
              <ErrorsPanel errors={open.errors ?? []} />
            </Card>
          </div>
        </>
      )}
    </>
  );
}
