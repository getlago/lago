# Monitoring

This document covers monitoring and observability for Lago's infrastructure components.

---

## Table of Contents

- [Sidekiq Monitoring](#sidekiq-monitoring)
  - [Architecture Overview](#architecture-overview)
  - [Basic Prometheus Metrics](#basic-prometheus-metrics)
  - [Sidekiq Pro Metrics (StatsD)](#sidekiq-pro-metrics-statsd)
  - [Recommended Alerts](#recommended-alerts)

---

## Sidekiq Monitoring

Lago exposes Sidekiq metrics through Prometheus, enabling comprehensive monitoring of background job processing. There are two layers of metrics available depending on your Sidekiq license.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Metrics Collection                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐      ┌─────────────────────┐      ┌────────────────┐  │
│  │   Sidekiq    │      │   Sidekiq Web UI    │      │   Prometheus   │  │
│  │   Workers    │─────▶│   + Prometheus      │─────▶│                │  │
│  │              │      │   Exporter          │      │                │  │
│  └──────────────┘      └─────────────────────┘      └────────────────┘  │
│                              :3000/prometheus/metrics                   │
│                                                                         │
│  ┌──────────────┐      ┌─────────────────────┐      ┌────────────────┐  │
│  │   Sidekiq    │      │   StatsD Exporter   │      │   Prometheus   │  │
│  │   Pro        │─────▶│   (DogStatsD)       │─────▶│                │  │
│  │   Middleware │      │                     │      │                │  │
│  └──────────────┘      └─────────────────────┘      └────────────────┘  │
│     (optional)           :12345/metrics                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Components:**

1. **Sidekiq Web UI with Prometheus Exporter** (`lago-sidekiqs` service)
   - Bundled with [`sidekiq/prometheus/exporter`](https://github.com/strech/sidekiq-prometheus-exporter) gem
   - Exposes metrics at `/prometheus/metrics`
   - Provides queue-level and global Sidekiq statistics
   - Configuration: [`lago-sidekiqs/config.ru`](https://github.com/getlago/lago-sidekiqs/blob/main/config.ru)

```ruby
# lago-sidekiqs/config.ru
require './app'
require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq/prometheus/exporter'
require 'sidekiq/throttled'
require 'sidekiq/throttled/web'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq::Web.use(Rack::Session::Cookie, secret: ENV['SESSION_SECRET'])

run Rack::URLMap.new('/' => Sidekiq::Web, '/prometheus/metrics' => Sidekiq::Prometheus::Exporter)
```

2. **Sidekiq Pro StatsD Metrics** (optional, requires Sidekiq Pro license)
   - Configured via `LAGO_SIDEKIQ_STATSD_ENDPOINT` environment variable
   - Uses Datadog StatsD client with `lago_api` namespace
   - Provides per-job execution metrics (duration, success/failure counts)
   - Configuration: [`lago-api/config/initializers/sidekiq.rb`](https://github.com/getlago/lago-api/blob/main/config/initializers/sidekiq.rb#L36-L61)

```ruby
# lago-api/config/initializers/sidekiq.rb
def configure_sidekiq_pro_metrics(config)
  statsd_endpoint = ENV.fetch("LAGO_SIDEKIQ_STATSD_ENDPOINT", nil)
  if statsd_endpoint.nil?
    Rails.logger.warn "LAGO_SIDEKIQ_STATSD_ENDPOINT not set, Sidekiq Pro metrics will not be reported"
    return
  end

  statsd_host, statsd_port = statsd_endpoint.split(":")
  if statsd_host.empty? || statsd_port.nil? || statsd_port.empty?
    Rails.logger.error "LAGO_SIDEKIQ_STATSD_ENDPOINT invalid format, expected host:port"
    return
  end

  require "datadog/statsd"

  config.dogstatsd = -> {
    Datadog::Statsd.new(statsd_host, statsd_port.to_i,
      tags: ["env:#{config[:environment]}", "service:sidekiq"],
      namespace: Rails.application.name)
  }

  config.server_middleware do |chain|
    require "sidekiq/middleware/server/statsd"
    chain.add Sidekiq::Middleware::Server::Statsd
  end
end
```

### Basic Prometheus Metrics

These metrics are available from the Sidekiq web service at `/prometheus/metrics` and work with both Sidekiq OSS and Pro.

#### Global Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `sidekiq_processed_jobs_total` | Counter | Total number of processed jobs (all-time) |
| `sidekiq_failed_jobs_total` | Counter | Total number of failed jobs (all-time) |
| `sidekiq_workers` | Gauge | Total number of worker threads across all processes |
| `sidekiq_processes` | Gauge | Number of Sidekiq processes running |
| `sidekiq_busy_workers` | Gauge | Number of workers currently executing jobs |
| `sidekiq_enqueued_jobs` | Gauge | Total number of jobs waiting in all queues |
| `sidekiq_scheduled_jobs` | Gauge | Number of jobs scheduled for future execution |
| `sidekiq_retry_jobs` | Gauge | Number of jobs waiting to be retried |
| `sidekiq_dead_jobs` | Gauge | Number of jobs in the dead queue |

#### Per-Host Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `sidekiq_host_processes` | Gauge | `host`, `quiet` | Number of processes per host. `quiet=true` indicates graceful shutdown |

#### Per-Queue Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `sidekiq_queue_latency_seconds` | Gauge | `name` | Time since oldest job was enqueued (queue delay) |
| `sidekiq_queue_enqueued_jobs` | Gauge | `name` | Number of jobs waiting in the queue |
| `sidekiq_queue_max_processing_time_seconds` | Gauge | `name` | Longest running job execution time |
| `sidekiq_queue_workers` | Gauge | `name` | Number of worker threads serving this queue |
| `sidekiq_queue_processes` | Gauge | `name` | Number of processes serving this queue |
| `sidekiq_queue_busy_workers` | Gauge | `name` | Number of workers currently processing jobs from this queue |

**Available Queues:**

| Queue | Worker Type |
|-------|-------------|
| `ai_agent` | AI Agent Worker |
| `analytics` | Analytics Worker |
| `billing` | Billing Worker |
| `clock` | Default Worker (clock jobs) |
| `clock_worker` | Dedicated Clock Worker |
| `default` | Default Worker |
| `events` | Events Worker |
| `high_priority` | Default Worker |
| `integrations` | Default Worker |
| `invoices` | Default Worker |
| `long_running` | Default Worker |
| `low_priority` | Default Worker |
| `mailers` | Default Worker |
| `pdfs` | PDF Worker |
| `providers` | Default Worker |
| `wallets` | Default Worker (deprecated) |
| `webhook` | Default Worker (webhook jobs) |
| `webhook_worker` | Dedicated Webhook Worker |

### Sidekiq Pro Metrics (StatsD)

When using Sidekiq Pro with `LAGO_SIDEKIQ_STATSD_ENDPOINT` configured, additional per-job metrics are available. These metrics are sent as DogStatsD and can be converted to Prometheus format using a StatsD exporter.

#### Configuration

Set the following environment variable to enable Sidekiq Pro metrics:

```bash
LAGO_SIDEKIQ_STATSD_ENDPOINT=statsd-exporter:9125
```

The metrics are tagged with:
- `env`: Environment name (e.g., `production`)
- `service`: Always `sidekiq`
- `queue`: Queue name
- `worker`: Job class name

#### Per-Job Metrics

All metrics use the `lago_api_` prefix (application namespace).

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `lago_api_jobs_count` | Counter | `queue`, `worker` | Total number of jobs executed |
| `lago_api_jobs_success` | Counter | `queue`, `worker` | Number of successfully completed jobs |
| `lago_api_jobs_failure` | Counter | `queue`, `worker`, `error_type` | Number of failed jobs by error type |
| `lago_api_jobs_perform` | Summary | `queue`, `worker` | Job execution duration (seconds) with p50, p90, p99 quantiles |
| `lago_api_jobs_recovered_fetch` | Counter | `queue` | Number of jobs recovered from interrupted fetches |

#### Example Queries

**Job failure rate by worker:**
```promql
rate(lago_api_jobs_failure[5m]) / rate(lago_api_jobs_count[5m])
```

**P99 execution time for billing jobs:**
```promql
lago_api_jobs_perform{queue="billing", quantile="0.99"}
```

**Top 10 slowest jobs (by median execution time):**
```promql
topk(10, lago_api_jobs_perform{quantile="0.5"})
```

**Jobs per second by queue:**
```promql
sum by (queue) (rate(lago_api_jobs_count[5m]))
```

### Recommended Alerts

#### Critical Alerts

```yaml
# Queue latency too high (jobs waiting too long)
- alert: SidekiqQueueLatencyHigh
  expr: sidekiq_queue_latency_seconds > 300
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Sidekiq queue {{ $labels.name }} has high latency"
    description: "Queue {{ $labels.name }} has jobs waiting for {{ $value | humanizeDuration }}"

# Dead jobs accumulating
- alert: SidekiqDeadJobsIncreasing
  expr: increase(sidekiq_dead_jobs[1h]) > 100
  labels:
    severity: critical
  annotations:
    summary: "Sidekiq dead jobs increasing rapidly"
    description: "{{ $value }} jobs moved to dead queue in the last hour"

# No workers available
- alert: SidekiqNoWorkers
  expr: sidekiq_workers == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "No Sidekiq workers available"
    description: "All Sidekiq workers are down"
```

#### Warning Alerts

```yaml
# Queue backlog building up
- alert: SidekiqQueueBacklog
  expr: sidekiq_queue_enqueued_jobs > 1000
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Sidekiq queue {{ $labels.name }} has backlog"
    description: "Queue {{ $labels.name }} has {{ $value }} jobs waiting"

# High failure rate
- alert: SidekiqHighFailureRate
  expr: |
    rate(lago_api_jobs_failure[5m])
    / rate(lago_api_jobs_count[5m]) > 0.05
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High job failure rate for {{ $labels.worker }}"
    description: "{{ $labels.worker }} has {{ $value | humanizePercentage }} failure rate"

# Worker process in quiet mode (shutting down)
- alert: SidekiqWorkerQuiet
  expr: sidekiq_host_processes{quiet="true"} > 0
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Sidekiq worker {{ $labels.host }} in quiet mode"
    description: "Worker has been shutting down for over 10 minutes"

# Slow job execution
- alert: SidekiqSlowJobs
  expr: lago_api_jobs_perform{quantile="0.99"} > 30
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Slow job execution for {{ $labels.worker }}"
    description: "P99 execution time is {{ $value }}s"
```

#### Informational Alerts

```yaml
# Retry queue has jobs
- alert: SidekiqRetryQueueNotEmpty
  expr: sidekiq_retry_jobs > 50
  for: 15m
  labels:
    severity: info
  annotations:
    summary: "Sidekiq retry queue has pending jobs"
    description: "{{ $value }} jobs waiting to be retried"
```

### Grafana Dashboard Recommendations

Key panels to include in your Sidekiq monitoring dashboard:

1. **Overview Row**
   - Total processed jobs (counter)
   - Current failure rate (gauge)
   - Active workers vs total workers
   - Total enqueued jobs

2. **Queue Health Row**
   - Queue latency by queue (time series)
   - Enqueued jobs by queue (stacked area)
   - Queue throughput (jobs/sec by queue)

3. **Worker Health Row**
   - Processes by host (table)
   - Busy workers over time
   - Workers in quiet mode

4. **Job Performance Row** (requires Sidekiq Pro)
   - P50/P90/P99 execution times by job
   - Top 10 slowest jobs
   - Failure rate by job type
   - Error breakdown by type

5. **Capacity Planning Row**
   - Jobs processed per hour (trend)
   - Queue depth trend
   - Worker utilization percentage

---

## Additional Resources

- [Worker Architecture](./architecture.md#worker-architecture) - Detailed queue configuration and worker setup
- [Clock System](./architecture.md#clock-system) - Scheduled job documentation
- [Resource Configuration Guide](./architecture.md#resource-configuration-guide) - Scaling recommendations
