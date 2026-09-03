#!/usr/bin/env python3
"""Live throughput / bottleneck view for a running stage-0 job.

Flink's job-level `read-records` counters in the REST overview update lazily
and made the first drain measurement unreadable. The per-subtask
`numRecordsOutPerSecond` gauges are the honest instrument, so this sums them
per operator and prints them next to busy time and backpressure — the two
numbers that say WHICH operator is the ceiling, which is the whole question
this PoC exists to answer.

  ./scripts/bench-watch.py [--jid <id>] [--interval 5] [--samples 60]
"""
import argparse, json, sys, time, urllib.request

BASE = "http://localhost:8081"

def get(path):
    with urllib.request.urlopen(BASE + path, timeout=15) as r:
        return json.load(r)

def running_job():
    for j in get("/jobs/overview")["jobs"]:
        if j["state"] == "RUNNING":
            return j["jid"]
    sys.exit("no RUNNING job")

def vertex_metrics(jid, vid, names):
    q = ",".join(names)
    return {m["id"]: float(m["value"]) for m in get(f"/jobs/{jid}/vertices/{vid}/metrics?get={q}")}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jid")
    ap.add_argument("--interval", type=float, default=5)
    ap.add_argument("--samples", type=int, default=60)
    a = ap.parse_args()
    jid = a.jid or running_job()
    job = get(f"/jobs/{jid}")
    print(f"job {jid} ({job['name']})")

    # Per vertex: pick the LAST operator's out-rate (what the vertex delivers),
    # plus busy/backpressure, summed/averaged over subtasks.
    plans = []
    for v in job["vertices"]:
        ids = [m["id"] for m in get(f"/jobs/{jid}/vertices/{v['id']}/metrics")]
        out = [i for i in ids if i.endswith("numRecordsOutPerSecond") and "." in i]
        # operator-scoped names look like "<subtask>.<Operator>.numRecordsOutPerSecond"
        ops = sorted({i.split(".", 1)[1] for i in out if i.count(".") >= 2})
        chosen = ops[-1] if ops else None
        busy = [i for i in ids if i.endswith(".busyTimeMsPerSecond") and i.count(".") == 1]
        bp = [i for i in ids if i.endswith(".backPressuredTimeMsPerSecond") and i.count(".") == 1]
        outs = [i for i in out if chosen and i.endswith(chosen)]
        plans.append((v["id"], v["name"].split("->")[0].strip()[:34], outs, busy, bp))

    print(f"{'time':>6}  " + "  ".join(f"{n:>36}" for _, n, _, _, _ in plans))
    print("        (rate = vertex out/s | busy avg/max over subtasks | bp = backpressured)")
    for s in range(a.samples):
        cells = []
        for vid, _, outs, busy, bp in plans:
            names = outs + busy + bp
            try:
                m = vertex_metrics(jid, vid, names)
            except Exception as e:
                cells.append(f"{'err':>34}")
                continue
            rate = sum(m.get(n, 0.0) for n in outs)
            bvals = [m.get(n, 0.0) / 10.0 for n in busy] or [0.0]   # % of a second
            p = sum(m.get(n, 0.0) for n in bp) / max(len(bp), 1) / 10.0
            # avg AND max: an average hides skew, and skew was the first thing
            # this benchmark got wrong (2 of 8 join subtasks doing all the work).
            cells.append(f"{rate:11,.0f}/s busy{sum(bvals)/len(bvals):3.0f}/{max(bvals):3.0f}% bp{p:4.0f}%")
        print(f"{s*a.interval:6.0f}  " + "  ".join(cells), flush=True)
        time.sleep(a.interval)

main()
