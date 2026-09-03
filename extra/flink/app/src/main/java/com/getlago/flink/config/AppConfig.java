package com.getlago.flink.config;

import com.amazonaws.services.kinesisanalytics.runtime.KinesisAnalyticsRuntime;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.Properties;

/**
 * Configuration with one shape in both environments.
 *
 * <p>On Amazon Managed Service for Apache Flink the values come from the
 * application's {@code PropertyGroups} (configured on the application, not
 * baked into the JAR). Locally there is no MSF runtime, so the same keys are
 * read from a properties file.
 *
 * <p>This indirection is the reason the JAR is portable: nothing in the
 * topology hardcodes {@code redpanda:9092} the way the RisingWave SQL does,
 * so promoting to MSK/RDS is a PropertyGroup change and not a code change.
 *
 * <p>The MSF property group is named {@value #PROPERTY_GROUP}. Locally, point
 * {@code LAGO_FLINK_CONFIG} at a file, or rely on the bundled
 * {@code local.properties} classpath resource.
 */
public final class AppConfig {

    public static final String PROPERTY_GROUP = "LagoUsage";
    private static final String LOCAL_CONFIG_ENV = "LAGO_FLINK_CONFIG";
    private static final String LOCAL_CONFIG_RESOURCE = "/local.properties";

    private final Properties props;
    private final boolean managed;

    private AppConfig(Properties props, boolean managed) {
        this.props = props;
        this.managed = managed;
    }

    public static AppConfig load() {
        return load(new String[0]);
    }

    /**
     * Loads configuration and layers command-line overrides on top of it.
     *
     * <p>Overrides are written {@code --key=value} or {@code --key value} and
     * are how a single JAR runs a benchmark sweep without a rebuild:
     *
     * <pre>
     *   flink run -d app.jar --stage0.sink.connector print
     *   flink run -d app.jar --pipeline.explain true
     *   flink run -d app.jar --pipeline.mini-batch.enabled true --pipeline.mini-batch.latency '250 ms'
     * </pre>
     *
     * <p>MSF does not pass application arguments, so on the platform this is
     * inert and every value still comes from the PropertyGroup — the override
     * layer cannot silently diverge production from what is configured there.
     */
    public static AppConfig load(String[] args) {
        Properties fromMsf = fromManagedRuntime();
        if (fromMsf != null) {
            return new AppConfig(withOverrides(fromMsf, args), true);
        }
        return new AppConfig(withOverrides(fromLocalFile(), args), false);
    }

    /** Applies {@code --key=value} / {@code --key value} pairs onto {@code base}. */
    private static Properties withOverrides(Properties base, String[] args) {
        if (args == null || args.length == 0) {
            return base;
        }
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if (!arg.startsWith("--")) {
                throw new IllegalArgumentException(
                        "Unrecognised argument '" + arg + "'; expected --key=value or --key value");
            }
            String body = arg.substring(2);
            int eq = body.indexOf('=');
            String key;
            String value;
            if (eq >= 0) {
                key = body.substring(0, eq);
                value = body.substring(eq + 1);
            } else {
                key = body;
                if (i + 1 >= args.length) {
                    throw new IllegalArgumentException("Argument --" + key + " has no value");
                }
                value = args[++i];
            }
            base.setProperty(key, value);
        }
        return base;
    }

    /**
     * @return the MSF property group, or null when not running on MSF.
     *     KinesisAnalyticsRuntime returns an empty map off-platform rather
     *     than throwing, so an absent group is the signal, not an exception.
     */
    private static Properties fromManagedRuntime() {
        try {
            Map<String, Properties> groups = KinesisAnalyticsRuntime.getApplicationProperties();
            if (groups == null || groups.isEmpty()) {
                return null;
            }
            return groups.get(PROPERTY_GROUP);
        } catch (IOException e) {
            // Off-platform the runtime cannot find its config file. Not fatal.
            return null;
        }
    }

    private static Properties fromLocalFile() {
        Properties p = new Properties();
        String path = System.getenv(LOCAL_CONFIG_ENV);
        try {
            if (path != null && !path.isBlank()) {
                try (InputStream in = Files.newInputStream(Path.of(path))) {
                    p.load(in);
                }
                return p;
            }
            try (InputStream in = AppConfig.class.getResourceAsStream(LOCAL_CONFIG_RESOURCE)) {
                if (in == null) {
                    throw new IllegalStateException(
                            "No MSF property group '" + PROPERTY_GROUP + "' and no local config: "
                                    + "set " + LOCAL_CONFIG_ENV + " or bundle " + LOCAL_CONFIG_RESOURCE);
                }
                p.load(in);
            }
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return p;
    }

    /** True when running on Amazon Managed Service for Apache Flink. */
    public boolean isManaged() {
        return managed;
    }

    public String get(String key) {
        String v = props.getProperty(key);
        if (v == null || v.isBlank()) {
            throw new IllegalStateException(
                    "Missing required config key '" + key + "' in "
                            + (managed ? "MSF property group " + PROPERTY_GROUP : "local config"));
        }
        return v;
    }

    public String get(String key, String fallback) {
        String v = props.getProperty(key);
        return (v == null || v.isBlank()) ? fallback : v;
    }

    public int getInt(String key, int fallback) {
        return Integer.parseInt(get(key, Integer.toString(fallback)));
    }

    public boolean getBoolean(String key, boolean fallback) {
        return Boolean.parseBoolean(get(key, Boolean.toString(fallback)));
    }

    /** All keys, for {@code ${placeholder}} substitution in SQL resources. */
    public Properties raw() {
        return props;
    }
}
