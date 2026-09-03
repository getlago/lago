package com.getlago.flink;

import com.getlago.flink.config.AppConfig;
import com.getlago.flink.config.SqlRunner;

import org.apache.flink.configuration.Configuration;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Duration;

/**
 * Entry point for the Lago realtime usage pipeline.
 *
 * <p>ONE main() that runs identically on a local Flink cluster and on Amazon
 * Managed Service for Apache Flink. Everything environment-specific arrives
 * through {@link AppConfig} (MSF PropertyGroups / local properties file).
 *
 * <h2>MSF constraints encoded here</h2>
 * <ul>
 *   <li>No cluster-level config is set programmatically. MSF 2.2+ <em>throws</em>
 *       when an application tries to set a Flink config it does not allow, so
 *       state backend, checkpointing and parallelism are left to the platform.
 *       Locally the equivalent settings live in {@code FLINK_PROPERTIES} in
 *       {@code docker-compose.flink.yml}, which is exactly the split MSF
 *       imposes.</li>
 *   <li>Only {@code table.exec.*} planner settings are set here — those are
 *       job-scoped, travel with the JAR, and are the ones that actually shape
 *       the operators we are benchmarking.</li>
 *   <li>Nothing writes outside {@code /tmp}: MSF mounts a read-only root
 *       filesystem.</li>
 * </ul>
 */
public final class LagoUsageJob {

    private static final Logger LOG = LoggerFactory.getLogger(LagoUsageJob.class);

    /** Comma-separated classpath SQL resources, run in order. */
    private static final String STAGES_KEY = "pipeline.stages";
    private static final String JOB_NAME_KEY = "pipeline.job-name";

    public static void main(String[] args) throws Exception {
        // Command-line --key=value pairs override the property source; see AppConfig.
        AppConfig config = AppConfig.load(args);
        LOG.info("Starting Lago usage pipeline (runtime={})", config.isManaged() ? "MSF" : "local");

        TableEnvironment tEnv = TableEnvironment.create(
                EnvironmentSettings.newInstance().inStreamingMode().build());

        applyPlannerConfig(tEnv, config);

        SqlRunner runner = new SqlRunner(tEnv, config);
        String stages = config.get(STAGES_KEY);
        for (String stage : stages.split(",")) {
            String resource = stage.trim();
            if (resource.isEmpty()) {
                continue;
            }
            LOG.info("Running SQL stage: {}", resource);
            runner.runResource(resource);
        }

        if (config.getBoolean("pipeline.explain", false)) {
            // Print and exit: no job is submitted, no Kafka consumer group is
            // joined, no replication slot is created.
            System.out.println("================ EXECUTION PLAN ================");
            System.out.println(runner.explain());
            System.out.println("===============================================");
            return;
        }

        LOG.info("Submitting {} INSERT statement(s) as one job", runner.insertCount());
        runner.execute(config.get(JOB_NAME_KEY, "lago-usage"));
    }

    /**
     * Job-scoped planner configuration.
     *
     * <p>{@code table.exec.state.ttl} is the Flink equivalent of the
     * RisingWave design's 32-day bounded working set. In RisingWave that
     * bound had to be built by hand — a {@code now()}-driven temporal filter
     * whose expiry retractions swept the operator state, landed into
     * append-only "firewall" tables with {@code retention_seconds}. The
     * measured 36-37k ev/s ceiling was localised to exactly that construct
     * (fragment 119: the NOW()-driven DynamicFilter feeding the dedup).
     * Here it is one config key handled by the state backend, which is the
     * single most important structural difference this benchmark is testing.
     */
    private static void applyPlannerConfig(TableEnvironment tEnv, AppConfig config) {
        Configuration conf = tEnv.getConfig().getConfiguration();

        int stateTtlDays = config.getInt("pipeline.state-ttl-days", 32);
        tEnv.getConfig().setIdleStateRetention(Duration.ofDays(stateTtlDays));

        // Mini-batch trades a bounded amount of latency for far fewer state
        // accesses on aggregations. Off by default so the first measurement is
        // the honest per-record cost; turn on to explore the latency/throughput
        // curve the way barrier_interval_ms was explored on RisingWave.
        if (config.getBoolean("pipeline.mini-batch.enabled", false)) {
            conf.setString("table.exec.mini-batch.enabled", "true");
            conf.setString("table.exec.mini-batch.allow-latency",
                    config.get("pipeline.mini-batch.latency", "250 ms"));
            conf.setString("table.exec.mini-batch.size",
                    config.get("pipeline.mini-batch.size", "5000"));
        }

        // Pinned so that CAST(TIMESTAMP AS TIMESTAMP_LTZ) on dimension
        // columns cannot drift with the host timezone. Rails writes these
        // columns in UTC; RisingWave's equivalent is an explicit
        // `AT TIME ZONE 'UTC'`.
        conf.setString("table.local-time-zone", config.get("pipeline.time-zone", "UTC"));

        // A CDC dimension source emits nothing between catalog changes, so its
        // watermark stops advancing and the event-time temporal join in stage 0
        // stalls behind it. Marking an idle source lets downstream watermarks
        // progress. This failure mode does not exist on RisingWave, whose
        // temporal join is processing-time.
        conf.setString("table.exec.source.idle-timeout",
                config.get("pipeline.source-idle-timeout", "10 s"));

        conf.setString("pipeline.name", config.get(JOB_NAME_KEY, "lago-usage"));
        LOG.info("Planner configured: state TTL {} days, mini-batch {}",
                stateTtlDays, config.getBoolean("pipeline.mini-batch.enabled", false));
    }

    private LagoUsageJob() {
    }
}
