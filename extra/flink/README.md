# Lago realtime usage on Apache Flink (PoC)

A second implementation of the RisingWave realtime usage pipeline
(`extra/risingwave/`), built to answer one question: **is the ~37k ev/s ceiling
measured on RisingWave a property of that engine, or of the problem?**

Production target is **Amazon Managed Service for Apache Flink** (MSF), so the
application is shaped as an MSF application from day one rather than retrofitted
later. See `ROADMAP.md` for the plan, the decisions and their evidence.

## Layout

```
app/                    Maven project -> ONE shaded uber-JAR (the MSF artifact)
  src/main/java/            LagoUsageJob (entry point), AppConfig, SqlRunner, udf/
  src/main/resources/sql/   the topology, as .sql — diffable against extra/risingwave/sql/
  src/main/resources/local.properties   local values for the LagoUsage property group
  src/test/java/            Go-parity suite for the UDFs
conf/msf-property-groups.example.json   the same keys, in AWS PropertyGroup shape
scripts/                build / up / submit / logs / down
docker-compose.flink.yml  LOCAL ONLY — MSF provisions its own cluster
```

## Run it

```sh
lago up -d                # dev stack must be up: network + redpanda
./scripts/build.sh        # no local JDK needed, builds in a container
./scripts/up.sh
./scripts/submit.sh
./scripts/logs.sh         # `print` sink output lands here
```

### The UI

Flink ships a full web UI — the analogue of the RisingWave dashboard at :5691.

- http://localhost:8081
- https://flink.lago.dev (via traefik, same convention as
  `risingwave.lago.dev` / `grafana.lago.dev` / `console.lago.dev`)

What is actually useful there, roughly in the order you will need it:

| View | Why it matters here |
|---|---|
| **Job graph** | shows the operators the planner chose — this is where you confirm a dedup compiled to `Deduplicate` and not to something with a clock-driven join in front of it, and where `ChangelogNormalize` showed up |
| **Backpressure** (per subtask) | the throughput investigation's main instrument — but remember it shows *victims, not causes* |
| **Flame graph** (per operator) | on-CPU profile of a single operator; enabled explicitly via `rest.flamegraph.enabled` (it is OFF by default) |
| **Checkpoints** | size, duration, alignment — the closest analogue to RisingWave's barrier timings |
| **Exceptions** | full restart history, with the root cause chain that named every CDC failure in Gate 1 |
| **Watermarks** | per-subtask event-time progress, once the usage buckets exist |

Everything in it is also on the REST API at the same port, which is how the
Gate 0/1 evidence in `ROADMAP.md` was collected — e.g.
`curl -s localhost:8081/jobs/<id> | jq`, and
`/jobs/<id>/metrics?get=numRestarts`.

On AWS there is an equivalent: MSF exposes the same Flink dashboard, plus
CloudWatch metrics.

## What is reusable on AWS, and what is not

| Reusable | Local only |
|---|---|
| `app/` — the JAR, its SQL, its UDFs | `docker-compose.flink.yml` |
| the config **contract** (`AppConfig` / property keys) | `local.properties` values |
| | `FLINK_PROPERTIES` cluster settings |

The split is not cosmetic. MSF provisions its own cluster and **throws** when an
application sets a Flink config it does not allow, so state backend,
checkpointing and parallelism must come from the platform. Locally those live in
`FLINK_PROPERTIES`, which reproduces the same boundary instead of hiding it —
the job code sets only `table.exec.*`.

Deploying to MSF is then: `mvn package -Dflink.version=2.3.0` → upload the JAR
to S3 → create the application with runtime Flink 2.3 → paste
`conf/msf-property-groups.example.json` (with real endpoints) as the property
groups → `StartApplication`. **No code change.**

> Secrets: the local file carries the dev Postgres password because the dev
> stack's credentials are already public in `docker-compose.dev.yml`. The MSF
> example deliberately omits `postgres.password` — on AWS it belongs in Secrets
> Manager, fetched at startup, not in a property group.

## Relationship to the RisingWave PoC

The SQL files are numbered to mirror `extra/risingwave/sql/` so the two
topologies can be read side by side. Where they diverge, the Flink file says so
in a comment and explains why. RisingWave is **stopped, not removed** — the
A/B needs both sides re-run on the same hardware.
