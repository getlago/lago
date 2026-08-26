import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { Banner, Card, HealthPills } from "../components/panels";
const toDraft = (c) => ({
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
export function Setup({ config, store, health, onSaved, onCheck, }) {
    const [d, setD] = useState(config ? toDraft(config) : null);
    const [saving, setSaving] = useState(false);
    const [msg, setMsg] = useState(null);
    const [err, setErr] = useState(null);
    useEffect(() => {
        if (config && !d)
            setD(toDraft(config));
    }, [config, d]);
    if (!d || !config)
        return _jsx(Card, { title: "Setup", children: "Loading\u2026" });
    const set = (k) => (v) => setD({ ...d, [k]: v });
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
            setMsg(`Saved to ${savedStore.dbPath}. Secrets stay server-side — the browser only ever sees masked values.`);
            onCheck();
        }
        catch (e) {
            setErr(e.message);
        }
        finally {
            setSaving(false);
        }
    };
    const T = (p) => (_jsxs("label", { className: "field", children: [p.label, _jsx("input", { type: p.type ?? "text", value: p.value, placeholder: p.placeholder, onChange: (e) => p.onChange(e.target.value), spellCheck: false }), p.note && _jsx("span", { className: "note", children: p.note })] }));
    const N = (p) => (_jsxs("label", { className: "field", children: [p.label, _jsx("input", { type: "number", value: p.value, onChange: (e) => p.onChange(Number(e.target.value)) }), p.note && _jsx("span", { className: "note", children: p.note })] }));
    return (_jsxs(_Fragment, { children: [err && _jsx(Banner, { kind: "bad", children: err }), msg && _jsx(Banner, { kind: "info", children: msg }), store && !store.configured && (_jsxs(Banner, { kind: "warn", children: [_jsx("b", { children: "Not configured yet." }), " Fill in the Lago API URL and key, the RisingWave pgwire URL and the ClickHouse URL, then Save. Settings are stored in a local SQLite database (", _jsx("code", { children: store.dbPath }), ") \u2014 there is no dotfile to maintain, and this screen is the only way in."] })), store?.importedFrom && (_jsxs(Banner, { kind: "info", children: ["Imported your existing ", _jsx("code", { children: store.importedFrom }), " into SQLite once and renamed it to", " ", _jsxs("code", { children: [store.importedFrom, ".imported"] }), ". Configuration now lives in the database and is edited here."] })), _jsx(Card, { title: "Connections", hint: store?.savedAt
                    ? `stored in SQLite · last saved ${new Date(store.savedAt).toLocaleString()}`
                    : "stored in a local SQLite database next to the app", right: _jsx(HealthPills, { health: health, onRefresh: onCheck }), children: _jsxs("div", { className: "grid cols-3", children: [T({
                            label: "Lago API URL",
                            value: d.lagoApiUrl,
                            onChange: set("lagoApiUrl"),
                            placeholder: "https://api.staging.example.com",
                        }), T({
                            label: "Lago API key",
                            value: d.lagoApiKey,
                            onChange: set("lagoApiKey"),
                            type: "password",
                            placeholder: config.lago.apiKeySet ? `stored: ${config.lago.apiKey}` : "required",
                            note: config.lago.apiKeySet ? "leave blank to keep the stored key" : "required — no key stored yet",
                        }), _jsx("div", {}), T({
                            label: "RisingWave pgwire URL",
                            value: d.rwUrl,
                            onChange: set("rwUrl"),
                            placeholder: "postgresql://user:pass@host.risingwave.cloud:4566/dev?sslmode=require",
                            note: "TLS is used automatically for *.risingwave.cloud or when sslmode=require is present",
                        }), T({ label: "RisingWave enriched table", value: d.rwEnriched, onChange: set("rwEnriched") }), T({ label: "RisingWave expanded table", value: d.rwExpanded, onChange: set("rwExpanded") }), T({
                            label: "ClickHouse HTTP(S) URL",
                            value: d.chUrl,
                            onChange: set("chUrl"),
                            placeholder: "https://host.clickhouse.cloud:8443",
                        }), T({ label: "ClickHouse user", value: d.chUser, onChange: set("chUser") }), T({
                            label: "ClickHouse password",
                            value: d.chPassword,
                            onChange: set("chPassword"),
                            type: "password",
                            note: config.clickhouse.passwordSet ? "leave blank to keep the stored password" : "no password stored yet",
                        }), T({ label: "ClickHouse database", value: d.chDatabase, onChange: set("chDatabase") })] }) }), _jsxs(Card, { title: "ClickHouse tables", hint: "the RisingWave shadow tables and the Go events-processor tables, measured side by side", children: [_jsxs("div", { className: "grid cols-4", children: [T({ label: "RW shadow · enriched", value: d.chRwEnriched, onChange: set("chRwEnriched") }), T({ label: "RW shadow · expanded", value: d.chRwExpanded, onChange: set("chRwExpanded") }), T({ label: "Go path · enriched", value: d.chGoEnriched, onChange: set("chGoEnriched") }), T({ label: "Go path · expanded", value: d.chGoExpanded, onChange: set("chGoExpanded") })] }), _jsxs("p", { style: { marginTop: 12, fontSize: 12, color: "var(--text-muted)" }, children: ["Measurement queries never use ", _jsx("code", { children: "FINAL" }), ", on either path: existence is existence,", " ", _jsx("code", { children: "min(enriched_at)" }), " returns the first insert regardless of row versions, and counts use", " ", _jsx("code", { children: "uniqExact" }), ". Every lookup is also narrowed to the subscriptions, metric codes and time window of the run so it uses the primary key instead of scanning the table."] })] }), _jsxs(Card, { title: "Direct produce to Redpanda", hint: "bypasses the Lago API on the send path \u2014 the only way to push the pipeline past what Lago itself can ingest", children: [_jsxs("div", { className: "grid cols-3", children: [T({
                                label: "Brokers",
                                value: d.kafkaBrokers,
                                onChange: set("kafkaBrokers"),
                                placeholder: "localhost:19092",
                                note: "comma-separated. From outside Docker this is the EXTERNAL listener (19092 in the dev stack), not redpanda:9092",
                            }), T({
                                label: "Raw events topic",
                                value: d.kafkaTopic,
                                onChange: set("kafkaTopic"),
                                note: "must equal LAGO_KAFKA_RAW_EVENTS_TOPIC — auto-creation is off, so a typo fails preflight instead of writing into a topic nobody reads",
                            }), T({
                                label: "Organization id",
                                value: d.kafkaOrganizationId,
                                onChange: set("kafkaOrganizationId"),
                                placeholder: "read from GET /organizations",
                                note: "the join key the whole pipeline resolves subscriptions and charges on. Blank = read it from Lago",
                            }), _jsxs("label", { className: "field", children: ["acks", _jsxs("select", { value: String(d.kafkaAcks), onChange: (e) => set("kafkaAcks")(Number(e.target.value)), children: [_jsx("option", { value: "1", children: "1 \u2014 leader ack" }), _jsx("option", { value: "-1", children: "-1 \u2014 all replicas" }), _jsx("option", { value: "0", children: "0 \u2014 fire and forget" })] }), _jsx("span", { className: "note", children: "this is what \"API response\" measures on a direct-produce run; acks=0 reports no rejection at all" })] }), _jsxs("label", { className: "field", children: ["Compression", _jsxs("select", { value: d.kafkaCompression, onChange: (e) => set("kafkaCompression")(e.target.value), children: [_jsx("option", { value: "none", children: "none" }), _jsx("option", { value: "gzip", children: "gzip" })] }), _jsx("span", { className: "note", children: "gzip trades sender CPU for network; none is the faithful default" })] }), T({
                                label: "source",
                                value: d.kafkaSource,
                                onChange: set("kafkaSource"),
                                note: "both consumers read http_ruby as \"custom expressions already evaluated\" — changing it measures a different code path",
                            }), T({ label: "Client id", value: d.kafkaClientId, onChange: set("kafkaClientId") }), _jsxs("label", { className: "field", children: ["TLS", _jsxs("div", { className: "row", style: { gap: 8, alignItems: "center", height: 32 }, children: [_jsx("input", { type: "checkbox", checked: d.kafkaSsl, onChange: (e) => set("kafkaSsl")(e.target.checked) }), _jsx("span", { style: { fontSize: 12 }, children: "connect over TLS" })] }), _jsx("span", { className: "note", children: "off for the local dev stack, on for Redpanda Cloud" })] }), _jsxs("label", { className: "field", children: ["SASL", _jsxs("select", { value: d.kafkaSaslMechanism, onChange: (e) => set("kafkaSaslMechanism")(e.target.value), children: [_jsx("option", { value: "", children: "none" }), _jsx("option", { value: "plain", children: "plain" }), _jsx("option", { value: "scram-sha-256", children: "scram-sha-256" }), _jsx("option", { value: "scram-sha-512", children: "scram-sha-512" })] }), _jsx("span", { className: "note", children: "left as none for the dev stack" })] }), d.kafkaSaslMechanism !== "" && (_jsxs(_Fragment, { children: [T({ label: "SASL username", value: d.kafkaSaslUsername, onChange: set("kafkaSaslUsername") }), T({
                                        label: "SASL password",
                                        value: d.kafkaSaslPassword,
                                        onChange: set("kafkaSaslPassword"),
                                        type: "password",
                                        note: config.kafka.sasl.passwordSet ? "leave blank to keep the stored password" : "no password stored yet",
                                    })] }))] }), _jsxs("p", { style: { marginTop: 12, fontSize: 12, color: "var(--text-muted)" }, children: ["The message produced is byte-shape identical to what ", _jsx("code", { children: "Events::KafkaProducerService" }), " writes \u2014", _jsx("code", { children: "timestamp" }), " as a JSON string of float seconds, ", _jsx("code", { children: "ingested_at" }), " without the trailing", " ", _jsx("code", { children: "Z" }), ", ", _jsx("code", { children: "precise_total_amount_cents" }), " defaulting to ", _jsx("code", { children: "\"0.0\"" }), ", keyed by", " ", _jsx("code", { children: "<organization_id>-<external_subscription_id>" }), ". What it cannot reproduce is what the API does ", _jsx("em", { children: "besides" }), " producing: for an organization whose events store is Postgres, the ", _jsx("code", { children: "events" }), " row and ", _jsx("code", { children: "PostProcessJob" }), " never happen, so any usage read not served by the realtime 15-minute buckets has nothing to read. Preflight says which case this organization is in."] })] }), _jsx(Card, { title: "HTTP to Lago", hint: "the send path's own limits \u2014 throughput is in-flight requests divided by round trip, and these decide what in-flight can be", children: _jsxs("div", { className: "grid cols-4", children: [N({
                            label: "Connections to Lago",
                            value: d.httpConnections,
                            onChange: set("httpConnections"),
                            note: "with HTTP/2 a handful multiplex everything; without it this is a hard ceiling on requests in flight",
                        }), _jsxs("label", { className: "field", children: ["HTTP/2", _jsxs("div", { className: "row", style: { gap: 8, alignItems: "center", height: 32 }, children: [_jsx("input", { type: "checkbox", checked: d.httpH2, onChange: (e) => set("httpH2")(e.target.checked) }), _jsx("span", { style: { fontSize: 12 }, children: "offer h2 in the TLS handshake" })] }), _jsx("span", { className: "note", children: "negotiated by ALPN \u2014 a Lago that only speaks 1.1 falls back silently" })] })] }) }), _jsxs(Card, { title: "Measurement", hint: "how visibility is polled \u2014 these numbers decide the resolution of every latency", children: [_jsxs("div", { className: "grid cols-4", children: [N({
                                label: "Poll tick (ms)",
                                value: d.pollTickMs,
                                onChange: set("pollTickMs"),
                                note: "this IS the resolution of every polled latency",
                            }), N({ label: "Stamp sweep (ms)", value: d.sweepMs, onChange: set("sweepMs"), note: "covers all events, not just probes" }), N({ label: "Probe timeout (ms)", value: d.probeTimeoutMs, onChange: set("probeTimeoutMs") }), N({
                                label: "Usage poll interval (ms)",
                                value: d.usagePollMs,
                                onChange: set("usagePollMs"),
                                note: "gap between current_usage requests",
                            }), N({
                                label: "Usage polls in flight",
                                value: d.usagePollConcurrency,
                                onChange: set("usagePollConcurrency"),
                                note: "pipelined; raising it tightens the bound but slows current_usage itself — watch the RTT on the run",
                            }), N({
                                label: "Wallet poll interval (ms)",
                                value: d.walletPollMs,
                                onChange: set("walletPollMs"),
                                note: "gap between GET /wallets requests — the reading is a stored column, so polling never triggers the refresh it times",
                            }), N({
                                label: "Wallet polls in flight",
                                value: d.walletPollConcurrency,
                                onChange: set("walletPollConcurrency"),
                                note: "pipelined; the wallets index serves the full payload, so its RTT can rival current_usage — watch it on the run",
                            })] }), _jsx("div", { className: "row", style: { marginTop: 14 }, children: _jsx("button", { className: "btn primary", onClick: save, disabled: saving, children: saving ? "Saving…" : "Save configuration" }) })] })] }));
}
