package com.getlago.flink;

import com.getlago.flink.config.AppConfig;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.cdc.connectors.postgres.source.PostgresSourceBuilder;
import org.apache.flink.cdc.debezium.JsonDebeziumDeserializationSchema;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

/**
 * PROBE, not production code.
 *
 * Answers one question: does a single {@code PostgresIncrementalSource} with
 * six tables in {@code tableList(...)} really use ONE replication slot?
 *
 * The Flink SQL postgres-cdc connector creates one slot per table and they
 * cannot be shared (measured: {@code ERROR: replication slot "..." already
 * exists}). The DataStream builder exposes {@code tableList(String...)} and a
 * single {@code slotName(String)}, which — if it behaves as the signature
 * suggests — removes the per-table slot cost that is the main objection to
 * keeping CDC inside Flink.
 *
 * Deliberately uses the built-in JsonDebeziumDeserializationSchema: this probe
 * is about slot accounting, not about the row shapes.
 */
public final class CdcSlotProbe {

    public static void main(String[] args) throws Exception {
        AppConfig config = AppConfig.load();

        PostgresSourceBuilder.PostgresIncrementalSource<String> source =
                PostgresSourceBuilder.PostgresIncrementalSource.<String>builder()
                        .hostname(config.get("postgres.hostname"))
                        .port(Integer.parseInt(config.get("postgres.port")))
                        .database(config.get("postgres.database"))
                        .username(config.get("postgres.username"))
                        .password(config.get("postgres.password"))
                        .schemaList(config.get("postgres.schema"))
                        .tableList(
                                "public.billable_metrics",
                                "public.subscriptions",
                                "public.charges",
                                "public.charge_filters",
                                "public.charge_filter_values",
                                "public.billable_metric_filters")
                        .slotName("flink_lago_dimensions")
                        .decodingPluginName("pgoutput")
                        .deserializer(new JsonDebeziumDeserializationSchema())
                        .build();

        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.fromSource(source, WatermarkStrategy.noWatermarks(), "pg-dimensions-cdc")
                .print("PROBE");
        env.execute("cdc-slot-probe");
    }

    private CdcSlotProbe() {
    }
}
