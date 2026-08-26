import { useEffect, useState } from "react";
import { api, type ConfigView, type Health, type StoreInfo } from "../lib/api";
import { Banner, Card, HealthPills } from "../components/panels";

type Draft = {
  lagoApiUrl: string;
  lagoApiKey: string;
  rwUrl: string;
  rwEnriched: string;
  rwExpanded: string;
  chUrl: string;
  chUser: string;
  chPassword: string;
  chDatabase: string;
  chRwEnriched: string;
  chRwExpanded: string;
  chGoEnriched: string;
  chGoExpanded: string;
  pollTickMs: number;
  sweepMs: number;
  probeTimeoutMs: number;
  kafkaBrokers: string;
  kafkaTopic: string;
  kafkaClientId: string;
  kafkaAcks: number;
  kafkaCompression: "none" | "gzip";
  kafkaSsl: boolean;
  kafkaSaslMechanism: "" | "plain" | "scram-sha-256" | "scram-sha-512";
  kafkaSaslUsername: string;
  kafkaSaslPassword: string;
  kafkaOrganizationId: string;
  kafkaSource: string;
  httpConnections: number;
  httpH2: boolean;
  usagePollMs: number;
  usagePollConcurrency: number;
  walletPollMs: number;
  walletPollConcurrency: number;
};

const toDraft = (c: ConfigView): Draft => ({
  lagoApiUrl: c.lago.apiUrl,
  lagoApiKey: "",
  rwUrl: c.risingwave.url,
  rwEnriched: c.risingwave.enrichedTable,
  rwExpanded: c.risingwave.expandedTable,
  chUrl: c.clickhouse.url,
  chUser: c.clickhouse.user,
  chPassword: "",
  chDatabase: c.clickhouse.database,
  chRwEnriched: c.clickhouse.rwEnrichedTable,
  chRwExpanded: c.clickhouse.rwExpandedTable,
  chGoEnriched: c.clickhouse.goEnrichedTable,
  chGoExpanded: c.clickhouse.goExpandedTable,
  kafkaBrokers: c.kafka.brokers,
  kafkaTopic: c.kafka.topic,
  kafkaClientId: c.kafka.clientId,
  kafkaAcks: c.kafka.acks,
  kafkaCompression: c.kafka.compression,
  kafkaSsl: c.kafka.ssl,
  kafkaSaslMechanism: c.kafka.sasl.mechanism,
  kafkaSaslUsername: c.kafka.sasl.username,
  kafkaSaslPassword: "",
  kafkaOrganizationId: c.kafka.organizationId,
  kafkaSource: c.kafka.source,
  httpConnections: c.http.connections,
  httpH2: c.http.h2,
  pollTickMs: c.measurement.pollTickMs,
  sweepMs: c.measurement.sweepMs,
  probeTimeoutMs: c.measurement.probeTimeoutMs,
  usagePollMs: c.measurement.usagePollMs,
  usagePollConcurrency: c.measurement.usagePollConcurrency,
  walletPollMs: c.measurement.walletPollMs,
  walletPollConcurrency: c.measurement.walletPollConcurrency,
});

export function Setup({
  config,
  store,
  health,
  onSaved,
  onCheck,
}: {
  config: ConfigView | null;
  store: StoreInfo | null;
  health: Health | null;
  onSaved: (c: ConfigView, store: StoreInfo) => void;
  onCheck: () => void;
}) {
  const [d, setD] = useState<Draft | null>(config ? toDraft(config) : null);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (config && !d) setD(toDraft(config));
  }, [config, d]);

  if (!d || !config) return <Card title="Setup">Loading…</Card>;

  const set = <K extends keyof Draft>(k: K) => (v: Draft[K]) => setD({ ...d, [k]: v });

  const save = async () => {
    setSaving(true);
    setErr(null);
    setMsg(null);
    try {
      // Empty secret fields mean "keep what is stored" — the UI never sees them.
      const patch = {
        lago: { apiUrl: d.lagoApiUrl, ...(d.lagoApiKey ? { apiKey: d.lagoApiKey } : {}) },
        risingwave: { url: d.rwUrl, enrichedTable: d.rwEnriched, expandedTable: d.rwExpanded },
        clickhouse: {
          url: d.chUrl,
          user: d.chUser,
          ...(d.chPassword ? { password: d.chPassword } : {}),
          database: d.chDatabase,
          rwEnrichedTable: d.chRwEnriched,
          rwExpandedTable: d.chRwExpanded,
          goEnrichedTable: d.chGoEnriched,
          goExpandedTable: d.chGoExpanded,
        },
        kafka: {
          brokers: d.kafkaBrokers,
          topic: d.kafkaTopic,
          clientId: d.kafkaClientId,
          acks: Number(d.kafkaAcks),
          compression: d.kafkaCompression,
          ssl: d.kafkaSsl,
          sasl: {
            mechanism: d.kafkaSaslMechanism,
            username: d.kafkaSaslUsername,
            ...(d.kafkaSaslPassword ? { password: d.kafkaSaslPassword } : {}),
          },
          organizationId: d.kafkaOrganizationId.trim(),
          source: d.kafkaSource,
        },
        http: { connections: Number(d.httpConnections), h2: d.httpH2 },
        measurement: {
          pollTickMs: Number(d.pollTickMs),
          sweepMs: Number(d.sweepMs),
          probeTimeoutMs: Number(d.probeTimeoutMs),
          usagePollMs: Number(d.usagePollMs),
          usagePollConcurrency: Number(d.usagePollConcurrency),
          walletPollMs: Number(d.walletPollMs),
          walletPollConcurrency: Number(d.walletPollConcurrency),
        },
      };
      const { config: saved, store: savedStore } = await api.putConfig(patch);
      onSaved(saved, savedStore);
      setD(toDraft(saved));
      setMsg(
        `Saved to ${savedStore.dbPath}. Secrets stay server-side — the browser only ever sees masked values.`,
      );
      onCheck();
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const T = (p: {
    label: string;
    value: string;
    onChange: (v: string) => void;
    note?: string;
    placeholder?: string;
    type?: string;
  }) => (
    <label className="field">
      {p.label}
      <input
        type={p.type ?? "text"}
        value={p.value}
        placeholder={p.placeholder}
        onChange={(e) => p.onChange(e.target.value)}
        spellCheck={false}
      />
      {p.note && <span className="note">{p.note}</span>}
    </label>
  );

  const N = (p: { label: string; value: number; onChange: (v: number) => void; note?: string }) => (
    <label className="field">
      {p.label}
      <input type="number" value={p.value} onChange={(e) => p.onChange(Number(e.target.value))} />
      {p.note && <span className="note">{p.note}</span>}
    </label>
  );

  return (
    <>
      {err && <Banner kind="bad">{err}</Banner>}
      {msg && <Banner kind="info">{msg}</Banner>}
      {store && !store.configured && (
        <Banner kind="warn">
          <b>Not configured yet.</b> Fill in the Lago API URL and key, the RisingWave pgwire URL and the ClickHouse URL,
          then Save. Settings are stored in a local SQLite database (<code>{store.dbPath}</code>) — there is no dotfile to
          maintain, and this screen is the only way in.
        </Banner>
      )}
      {store?.importedFrom && (
        <Banner kind="info">
          Imported your existing <code>{store.importedFrom}</code> into SQLite once and renamed it to{" "}
          <code>{store.importedFrom}.imported</code>. Configuration now lives in the database and is edited here.
        </Banner>
      )}

      <Card
        title="Connections"
        hint={
          store?.savedAt
            ? `stored in SQLite · last saved ${new Date(store.savedAt).toLocaleString()}`
            : "stored in a local SQLite database next to the app"
        }
        right={<HealthPills health={health} onRefresh={onCheck} />}
      >
        <div className="grid cols-3">
          {T({
            label: "Lago API URL",
            value: d.lagoApiUrl,
            onChange: set("lagoApiUrl"),
            placeholder: "https://api.staging.example.com",
          })}
          {T({
            label: "Lago API key",
            value: d.lagoApiKey,
            onChange: set("lagoApiKey"),
            type: "password",
            placeholder: config.lago.apiKeySet ? `stored: ${config.lago.apiKey}` : "required",
            note: config.lago.apiKeySet ? "leave blank to keep the stored key" : "required — no key stored yet",
          })}
          <div />
          {T({
            label: "RisingWave pgwire URL",
            value: d.rwUrl,
            onChange: set("rwUrl"),
            placeholder: "postgresql://user:pass@host.risingwave.cloud:4566/dev?sslmode=require",
            note: "TLS is used automatically for *.risingwave.cloud or when sslmode=require is present",
          })}
          {T({ label: "RisingWave enriched table", value: d.rwEnriched, onChange: set("rwEnriched") })}
          {T({ label: "RisingWave expanded table", value: d.rwExpanded, onChange: set("rwExpanded") })}
          {T({
            label: "ClickHouse HTTP(S) URL",
            value: d.chUrl,
            onChange: set("chUrl"),
            placeholder: "https://host.clickhouse.cloud:8443",
          })}
          {T({ label: "ClickHouse user", value: d.chUser, onChange: set("chUser") })}
          {T({
            label: "ClickHouse password",
            value: d.chPassword,
            onChange: set("chPassword"),
            type: "password",
            note: config.clickhouse.passwordSet ? "leave blank to keep the stored password" : "no password stored yet",
          })}
          {T({ label: "ClickHouse database", value: d.chDatabase, onChange: set("chDatabase") })}
        </div>
      </Card>

      <Card
        title="ClickHouse tables"
        hint="the RisingWave shadow tables and the Go events-processor tables, measured side by side"
      >
        <div className="grid cols-4">
          {T({ label: "RW shadow · enriched", value: d.chRwEnriched, onChange: set("chRwEnriched") })}
          {T({ label: "RW shadow · expanded", value: d.chRwExpanded, onChange: set("chRwExpanded") })}
          {T({ label: "Go path · enriched", value: d.chGoEnriched, onChange: set("chGoEnriched") })}
          {T({ label: "Go path · expanded", value: d.chGoExpanded, onChange: set("chGoExpanded") })}
        </div>
        <p style={{ marginTop: 12, fontSize: 12, color: "var(--text-muted)" }}>
          Measurement queries never use <code>FINAL</code>, on either path: existence is existence,{" "}
          <code>min(enriched_at)</code> returns the first insert regardless of row versions, and counts use{" "}
          <code>uniqExact</code>. Every lookup is also narrowed to the subscriptions, metric codes and time window of the
          run so it uses the primary key instead of scanning the table.
        </p>
      </Card>

      <Card
        title="Direct produce to Redpanda"
        hint="bypasses the Lago API on the send path — the only way to push the pipeline past what Lago itself can ingest"
      >
        <div className="grid cols-3">
          {T({
            label: "Brokers",
            value: d.kafkaBrokers,
            onChange: set("kafkaBrokers"),
            placeholder: "localhost:19092",
            note: "comma-separated. From outside Docker this is the EXTERNAL listener (19092 in the dev stack), not redpanda:9092",
          })}
          {T({
            label: "Raw events topic",
            value: d.kafkaTopic,
            onChange: set("kafkaTopic"),
            note: "must equal LAGO_KAFKA_RAW_EVENTS_TOPIC — auto-creation is off, so a typo fails preflight instead of writing into a topic nobody reads",
          })}
          {T({
            label: "Organization id",
            value: d.kafkaOrganizationId,
            onChange: set("kafkaOrganizationId"),
            placeholder: "read from GET /organizations",
            note: "the join key the whole pipeline resolves subscriptions and charges on. Blank = read it from Lago",
          })}
          <label className="field">
            acks
            <select
              value={String(d.kafkaAcks)}
              onChange={(e) => set("kafkaAcks")(Number(e.target.value))}
            >
              <option value="1">1 — leader ack</option>
              <option value="-1">-1 — all replicas</option>
              <option value="0">0 — fire and forget</option>
            </select>
            <span className="note">
              this is what "API response" measures on a direct-produce run; acks=0 reports no rejection at all
            </span>
          </label>
          <label className="field">
            Compression
            <select
              value={d.kafkaCompression}
              onChange={(e) => set("kafkaCompression")(e.target.value as Draft["kafkaCompression"])}
            >
              <option value="none">none</option>
              <option value="gzip">gzip</option>
            </select>
            <span className="note">gzip trades sender CPU for network; none is the faithful default</span>
          </label>
          {T({
            label: "source",
            value: d.kafkaSource,
            onChange: set("kafkaSource"),
            note: "both consumers read http_ruby as \"custom expressions already evaluated\" — changing it measures a different code path",
          })}
          {T({ label: "Client id", value: d.kafkaClientId, onChange: set("kafkaClientId") })}
          <label className="field">
            TLS
            <div className="row" style={{ gap: 8, alignItems: "center", height: 32 }}>
              <input type="checkbox" checked={d.kafkaSsl} onChange={(e) => set("kafkaSsl")(e.target.checked)} />
              <span style={{ fontSize: 12 }}>connect over TLS</span>
            </div>
            <span className="note">off for the local dev stack, on for Redpanda Cloud</span>
          </label>
          <label className="field">
            SASL
            <select
              value={d.kafkaSaslMechanism}
              onChange={(e) => set("kafkaSaslMechanism")(e.target.value as Draft["kafkaSaslMechanism"])}
            >
              <option value="">none</option>
              <option value="plain">plain</option>
              <option value="scram-sha-256">scram-sha-256</option>
              <option value="scram-sha-512">scram-sha-512</option>
            </select>
            <span className="note">left as none for the dev stack</span>
          </label>
          {d.kafkaSaslMechanism !== "" && (
            <>
              {T({ label: "SASL username", value: d.kafkaSaslUsername, onChange: set("kafkaSaslUsername") })}
              {T({
                label: "SASL password",
                value: d.kafkaSaslPassword,
                onChange: set("kafkaSaslPassword"),
                type: "password",
                note: config.kafka.sasl.passwordSet ? "leave blank to keep the stored password" : "no password stored yet",
              })}
            </>
          )}
        </div>
        <p style={{ marginTop: 12, fontSize: 12, color: "var(--text-muted)" }}>
          The message produced is byte-shape identical to what <code>Events::KafkaProducerService</code> writes —
          <code>timestamp</code> as a JSON string of float seconds, <code>ingested_at</code> without the trailing{" "}
          <code>Z</code>, <code>precise_total_amount_cents</code> defaulting to <code>"0.0"</code>, keyed by{" "}
          <code>&lt;organization_id&gt;-&lt;external_subscription_id&gt;</code>. What it cannot reproduce is what the API
          does <em>besides</em> producing: for an organization whose events store is Postgres, the <code>events</code> row
          and <code>PostProcessJob</code> never happen, so any usage read not served by the realtime 15-minute buckets has
          nothing to read. Preflight says which case this organization is in.
        </p>
      </Card>

      <Card
        title="HTTP to Lago"
        hint="the send path's own limits — throughput is in-flight requests divided by round trip, and these decide what in-flight can be"
      >
        <div className="grid cols-4">
          {N({
            label: "Connections to Lago",
            value: d.httpConnections,
            onChange: set("httpConnections"),
            note: "with HTTP/2 a handful multiplex everything; without it this is a hard ceiling on requests in flight",
          })}
          <label className="field">
            HTTP/2
            <div className="row" style={{ gap: 8, alignItems: "center", height: 32 }}>
              <input type="checkbox" checked={d.httpH2} onChange={(e) => set("httpH2")(e.target.checked)} />
              <span style={{ fontSize: 12 }}>offer h2 in the TLS handshake</span>
            </div>
            <span className="note">negotiated by ALPN — a Lago that only speaks 1.1 falls back silently</span>
          </label>
        </div>
      </Card>

      <Card title="Measurement" hint="how visibility is polled — these numbers decide the resolution of every latency">
        <div className="grid cols-4">
          {N({
            label: "Poll tick (ms)",
            value: d.pollTickMs,
            onChange: set("pollTickMs"),
            note: "this IS the resolution of every polled latency",
          })}
          {N({ label: "Stamp sweep (ms)", value: d.sweepMs, onChange: set("sweepMs"), note: "covers all events, not just probes" })}
          {N({ label: "Probe timeout (ms)", value: d.probeTimeoutMs, onChange: set("probeTimeoutMs") })}
          {N({
            label: "Usage poll interval (ms)",
            value: d.usagePollMs,
            onChange: set("usagePollMs"),
            note: "gap between current_usage requests",
          })}
          {N({
            label: "Usage polls in flight",
            value: d.usagePollConcurrency,
            onChange: set("usagePollConcurrency"),
            note: "pipelined; raising it tightens the bound but slows current_usage itself — watch the RTT on the run",
          })}
          {N({
            label: "Wallet poll interval (ms)",
            value: d.walletPollMs,
            onChange: set("walletPollMs"),
            note: "gap between GET /wallets requests — the reading is a stored column, so polling never triggers the refresh it times",
          })}
          {N({
            label: "Wallet polls in flight",
            value: d.walletPollConcurrency,
            onChange: set("walletPollConcurrency"),
            note: "pipelined; the wallets index serves the full payload, so its RTT can rival current_usage — watch it on the run",
          })}
        </div>
        <div className="row" style={{ marginTop: 14 }}>
          <button className="btn primary" onClick={save} disabled={saving}>
            {saving ? "Saving…" : "Save configuration"}
          </button>
        </div>
      </Card>
    </>
  );
}
