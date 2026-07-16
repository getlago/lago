# frozen_string_literal: true

require "benchmark"

module Events
  module Stores
    module Utils
      # Generic ClickHouse SQL performance benchmarking.
      #
      # Given a hash of { label => sql_string }, this service runs each query N times in
      # randomized order, tags each run via log_comment, then pulls server-side
      # metrics (query_duration_ms, memory_usage, read_rows, read_bytes,
      # result_rows) from system.query_log.
      # Returns medians as a Hash and prints a comparison table.
      #
      # It's a console-only utility, no specs.
      #
      # Usage:
      #
      #   Events::Stores::Utils::ClickhouseBenchmark.compare(
      #     {
      #       "argmax"   => "SELECT ...",
      #       "two_pass" => "WITH latest AS (...) ..."
      #     },
      #     repetitions: 5,
      #     cold_run: false
      #   )
      #
      # cold_run: if true, disables the uncompressed cache for tagged queries
      # only via SETTINGS use_uncompressed_cache = 0.
      class ClickhouseBenchmark
        include Events::Stores::Utils::ClickhouseSqlHelpers

        TAG_PREFIX = "ch_bench"

        def self.compare(queries, repetitions: 5, cold_run: false)
          new(
            queries:,
            repetitions:,
            cold_run:
          ).compare
        end

        def initialize(queries:, repetitions:, cold_run:)
          @queries = queries
          @repetitions = repetitions
          @cold_run = cold_run
          @run_id = SecureRandom.uuid
        end

        def compare
          wall_times = execute_repetitions
          flush_query_log
          server_rows = fetch_query_log_rows

          metrics = build_metrics(wall_times, server_rows)
          print_table(metrics)
          metrics
        end

        private

        attr_reader :queries, :repetitions, :cold_run, :run_id

        def execute_repetitions
          wall = queries.each_key.with_object({}) { |label, h| h[label] = [] }

          repetitions.times do |rep_idx|
            queries.to_a.shuffle.each do |label, sql|
              tag = tag_for(label, rep_idx)
              tagged_sql = with_settings(sql, tag)

              elapsed = Benchmark.realtime do
                ClickhouseConnection.connection_with_retry do |connection|
                  connection.select_all(tagged_sql).to_a
                end
              end

              wall[label] << (elapsed * 1000).to_i
            end
          end

          wall
        end

        def tag_for(label, rep_idx)
          "#{TAG_PREFIX}_#{run_id}_#{sanitize_label(label)}_#{rep_idx}"
        end

        def sanitize_label(label)
          label.to_s.gsub(/[^a-zA-Z0-9]+/, "_")
        end

        def with_settings(sql, tag)
          settings = ["log_comment = #{quote(tag)}"]
          settings << "use_uncompressed_cache = 0" if cold_run

          settings_sql = settings.join(", ")

          if sql.match?(/\bSETTINGS\b/i)
            "#{sql}, #{settings_sql}"
          else
            "#{sql} SETTINGS #{settings_sql}"
          end
        end

        def flush_query_log
          ClickhouseConnection.connection_with_retry do |connection|
            connection.execute("SYSTEM FLUSH LOGS")
          end
        rescue => e
          warn "SYSTEM FLUSH LOGS failed (#{e.class}: #{e.message}); falling back to sleep."
          sleep 8
        end

        def fetch_query_log_rows
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              "SELECT log_comment, query_duration_ms, memory_usage, read_rows, read_bytes, result_rows " \
              "FROM system.query_log " \
              "WHERE type = 'QueryFinish' AND log_comment LIKE ?",
              "#{TAG_PREFIX}_#{run_id}_%"
            ]
          )

          ClickhouseConnection.connection_with_retry do |connection|
            connection.select_all(sql).to_a
          end
        rescue => e
          warn "Could not read system.query_log (#{e.class}: #{e.message}); server metrics unavailable."
          []
        end

        def build_metrics(wall_times, server_rows)
          grouped = server_rows.group_by { |row| parse_label_key(row["log_comment"]) }

          queries.each_key.with_object({}) do |label, out|
            key = sanitize_label(label)
            runs = grouped[key] || []

            out[label] = {
              wall_ms_median: median(wall_times[label]),
              duration_ms_median: median(runs.map { |r| r["query_duration_ms"].to_i }),
              memory_usage_median: median(runs.map { |r| r["memory_usage"].to_i }),
              read_rows: runs.first&.dig("read_rows").to_i,
              read_bytes: runs.first&.dig("read_bytes").to_i,
              result_rows: runs.first&.dig("result_rows").to_i,
              wall_ms_runs: wall_times[label],
              server_runs: runs
            }
          end
        end

        def parse_label_key(log_comment)
          return nil if log_comment.nil?

          match = log_comment.match(/\A#{TAG_PREFIX}_[0-9a-f-]+_(.+)_\d+\z/o)
          match && match[1]
        end

        def median(values)
          return 0 if values.blank?

          sorted = values.sort
          mid = sorted.size / 2
          if sorted.size.odd?
            sorted[mid]
          else
            (sorted[mid - 1] + sorted[mid]) / 2
          end
        end

        # rubocop:disable Rails/Output
        def print_table(metrics)
          puts ""
          cold_suffix = cold_run ? "  [cold: use_uncompressed_cache=0]" : ""
          puts "Repetitions: #{repetitions} (median reported)#{cold_suffix}"
          puts ""

          label_width = [metrics.keys.map { |k| k.to_s.length }.max || 0, 18].max
          header = format(
            "%-#{label_width}s |  Server ms |    Wall ms |     Peak mem |    Rows read |   Bytes read",
            "Approach"
          )
          puts header
          puts "-" * header.length

          metrics.each do |label, m|
            puts format(
              "%-#{label_width}s | %10d | %10d | %12s | %12s | %12s",
              label,
              m[:duration_ms_median],
              m[:wall_ms_median],
              format_bytes(m[:memory_usage_median]),
              format_number(m[:read_rows]),
              format_bytes(m[:read_bytes])
            )
          end
          puts ""
        end
        # rubocop:enable Rails/Output

        def format_bytes(bytes)
          bytes = bytes.to_i
          return "0 B" if bytes.zero?

          units = %w[B KiB MiB GiB TiB]
          exp = (Math.log(bytes) / Math.log(1024)).floor
          exp = [exp, units.size - 1].min
          format("%.1f %s", bytes.to_f / (1024**exp), units[exp])
        end

        def format_number(n)
          n.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
        end
      end
    end
  end
end
