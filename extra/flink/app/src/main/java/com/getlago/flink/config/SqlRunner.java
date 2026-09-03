package com.getlago.flink.config;

import org.apache.flink.table.api.StatementSet;
import org.apache.flink.table.api.TableEnvironment;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Properties;

/**
 * Loads SQL from classpath resources, substitutes {@code ${placeholders}} from
 * {@link AppConfig}, and runs the statements against a {@link TableEnvironment}.
 *
 * <p>Why the topology is SQL-in-resources rather than SQL-in-Java-strings:
 * MSF deploys a JAR, not a SQL script, so the SQL has to live inside the
 * artifact — but keeping it in {@code .sql} files means it stays diffable
 * against {@code extra/risingwave/sql/}, which is the whole point of the
 * comparison.
 *
 * <p>All {@code INSERT INTO} statements are collected into a single
 * {@link StatementSet} so the pipeline runs as ONE Flink job with one shared
 * set of sources. Submitting them separately would open a duplicate Kafka
 * consumer and a duplicate CDC replication slot per statement.
 */
public final class SqlRunner {

    private final TableEnvironment tEnv;
    private final Properties vars;
    private final StatementSet inserts;
    private int insertCount = 0;

    public SqlRunner(TableEnvironment tEnv, AppConfig config) {
        this.tEnv = tEnv;
        this.vars = config.raw();
        this.inserts = tEnv.createStatementSet();
    }

    /** Runs every statement in a classpath SQL resource, e.g. {@code /sql/00_source.sql}. */
    public void runResource(String resource) {
        String body = readResource(resource);
        for (String statement : splitStatements(substitute(body))) {
            if (statement.toUpperCase(Locale.ROOT).startsWith("INSERT")) {
                inserts.addInsertSql(statement);
                insertCount++;
            } else {
                tEnv.executeSql(statement);
            }
        }
    }

    /**
     * Returns the planner's execution plan for the accumulated INSERTs WITHOUT
     * submitting anything.
     *
     * <p>Reading the plan is not a nicety here, it is the experiment. The
     * RisingWave ceiling was a plan-shape problem — a clock-driven
     * DynamicFilter in front of the dedup — and naming it took days of
     * elimination on a running cluster. Flink hands the same answer over
     * statically, for free, before a single event is processed.
     */
    public String explain() {
        if (insertCount == 0) {
            throw new IllegalStateException("No INSERT statements were registered — nothing to explain");
        }
        return inserts.explain();
    }

    /** Submits the accumulated INSERTs as one job. No-op when there are none. */
    public void execute(String jobName) {
        if (insertCount == 0) {
            throw new IllegalStateException("No INSERT statements were registered — nothing to run");
        }
        inserts.execute();
    }

    public int insertCount() {
        return insertCount;
    }

    private String readResource(String resource) {
        try (InputStream in = SqlRunner.class.getResourceAsStream(resource)) {
            if (in == null) {
                throw new IllegalArgumentException("SQL resource not found on classpath: " + resource);
            }
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    /** Replaces {@code ${key}} with the config value; unknown keys are an error. */
    private String substitute(String sql) {
        StringBuilder out = new StringBuilder(sql.length());
        int i = 0;
        while (i < sql.length()) {
            int start = sql.indexOf("${", i);
            if (start < 0) {
                out.append(sql, i, sql.length());
                break;
            }
            int end = sql.indexOf('}', start);
            if (end < 0) {
                out.append(sql, i, sql.length());
                break;
            }
            String key = sql.substring(start + 2, end);
            String value = vars.getProperty(key);
            if (value == null) {
                throw new IllegalStateException("SQL references ${" + key + "} but no such config key is set");
            }
            out.append(sql, i, start).append(value);
            i = end + 1;
        }
        return out.toString();
    }

    /**
     * Splits on top-level semicolons. Line comments are stripped first, and
     * semicolons inside single-quoted literals are ignored — enough for DDL
     * with JSON options and WHERE clauses. Dollar-quoted bodies (RisingWave's
     * inline-Rust style) are deliberately NOT supported: Flink UDFs are Java
     * classes registered from code, so no SQL file here contains one.
     */
    static List<String> splitStatements(String sql) {
        List<String> out = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inString = false;
        String[] lines = sql.split("\n", -1);
        for (String line : lines) {
            String working = inString ? line : stripLineComment(line);
            for (int i = 0; i < working.length(); i++) {
                char c = working.charAt(i);
                if (c == '\'') {
                    // '' is an escaped quote inside a literal.
                    if (inString && i + 1 < working.length() && working.charAt(i + 1) == '\'') {
                        current.append("''");
                        i++;
                        continue;
                    }
                    inString = !inString;
                    current.append(c);
                } else if (c == ';' && !inString) {
                    addIfNotBlank(out, current);
                    current.setLength(0);
                } else {
                    current.append(c);
                }
            }
            current.append('\n');
        }
        addIfNotBlank(out, current);
        return out;
    }

    private static String stripLineComment(String line) {
        boolean inString = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (c == '\'') {
                inString = !inString;
            } else if (!inString && c == '-' && i + 1 < line.length() && line.charAt(i + 1) == '-') {
                return line.substring(0, i);
            }
        }
        return line;
    }

    private static void addIfNotBlank(List<String> out, StringBuilder sb) {
        String s = sb.toString().trim();
        if (!s.isEmpty()) {
            out.add(s);
        }
    }
}
