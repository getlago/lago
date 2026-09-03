-- Raw billing events, exactly as produced to Kafka by the API / ingest
-- services. Mirrors extra/risingwave/sql/00_source_events_raw.sql so the two
-- pipelines can be diffed statement by statement.
--
-- DELIBERATE DIFFERENCE FROM THE RISINGWAVE SOURCE: `properties` is declared
-- STRING (raw JSON text), not a parsed JSON type. RisingWave has a native
-- JSONB column type; Flink's options are STRING + parse-in-UDF,
-- MAP<STRING,STRING>, or the 2.x VARIANT type. Which of the three is
-- cheapest on the hot path is an open question and a measured gate in the
-- ROADMAP, not something to assume — per-event JSON parsing is precisely the
-- cost that could make or break the JVM UDF comparison.
--
-- `timestamp` is STRING because producers send it as a JSON string
-- (e.g. "1786027675.796"); it is cast downstream.
CREATE TABLE IF NOT EXISTS events_raw (
    organization_id            STRING,
    external_subscription_id   STRING,
    transaction_id             STRING,
    code                       STRING,
    properties                 STRING,
    precise_total_amount_cents STRING,
    source                     STRING,
    `timestamp`                STRING,
    -- The payload also carries source_metadata.reprocess; deliberately not
    -- declared — events are immutable, there is no in-stream correction path.
    source_metadata            ROW<api_post_processed BOOLEAN>,
    ingested_at                TIMESTAMP(3),

    -- Broker append time: the only trustworthy per-event clock, and the one
    -- the RisingWave pipeline uses to drive its bounded windows. Unlike
    -- RisingWave's proctime() this is NOT barrier-aligned, so it is also
    -- usable for latency math.
    kafka_timestamp            TIMESTAMP_LTZ(3) METADATA FROM 'timestamp' VIRTUAL,
    -- Ingest-side processing clock: instrumentation, and the ORDER BY of the
    -- stage-0 first-wins dedup.
    flink_received_at          AS PROCTIME(),
    -- REQUIRED for the stage-0 temporal join. Flink rejects processing-time
    -- temporal joins outright ("Processing-time temporal join is not
    -- supported yet"), so unlike RisingWave's
    -- `FOR SYSTEM_TIME AS OF PROCTIME()` this pipeline must be event-time and
    -- therefore needs watermarks. The broker append time is the right clock:
    -- it is monotonic per partition and independent of producer clocks.
    --
    -- Cast to TIMESTAMP(3) because both sides of an event-time temporal join
    -- must share a rowtime type, and the dimension side's is Postgres
    -- `timestamp without time zone`. The cast lives HERE, on the append-only
    -- side, because putting a computed rowtime on the changelog side crashes
    -- the planner (see 01_cdc_dimensions.sql). table.local-time-zone is
    -- pinned to UTC so this cannot drift with the host.
    event_rowtime              AS CAST(kafka_timestamp AS TIMESTAMP(3)),
    WATERMARK FOR event_rowtime AS event_rowtime - INTERVAL '5' SECOND
) WITH (
    'connector'                     = 'kafka',
    'topic'                         = '${kafka.topic.events-raw}',
    'properties.bootstrap.servers'  = '${kafka.bootstrap.servers}',
    'properties.group.id'           = '${kafka.group.id}',
    'scan.startup.mode'             = '${kafka.startup.mode}',
    'format'                        = 'json',
    -- A malformed payload must not take the job down; the RisingWave source
    -- is equally tolerant.
    'json.ignore-parse-errors'      = 'true',
    'json.timestamp-format.standard'= 'ISO-8601'
);
