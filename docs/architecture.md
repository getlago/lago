# Application Architecture

This document summarizes the application's architecture and core flows.

---

## Table of Contents

- [Global Architecture Diagram](#global-architecture-diagram)
- [System Overview](#system-overview)
- [Worker Architecture](#worker-architecture)
  - [Worker Flow & Error Handling](#worker-flow--error-handling)
  - [Complete Worker Reference](#complete-worker-reference)
  - [Resource Configuration Guide](#resource-configuration-guide)
- [Clock System](#clock-system)
- [Redis Architecture](#redis-architecture)
- [Encryption & Security](#encryption--security)
- [Usage Event](#usage-event)
- [Billing Creation](#billing-creation)
- [Glossary](#glossary)

---

## Global Architecture Diagram

Below is a conceptual diagram representing the main components and their interactions within the application:

![Global Architecture Diagram](arch_diagram.png)

---

## System Overview

Lago API is a Rails application running on AWS. The architecture consists of several key components:

- **Main API**: Enqueues most workload into Sidekiq jobs for asynchronous processing
- **Sidekiq**: A core component that handles background job processing using Redis for job storage
- **Clock process**: A separate Clockwork process that schedules recurring jobs
- **Multiple queues**: Jobs are distributed across different queues based on the type of work and configuration

---

## Worker Architecture

### Default Worker Configuration

The main worker listens on the following queues (in priority order):

| Queue | Purpose |
|-------|---------|
| `high_priority` | Urgent tasks requiring immediate processing |
| `default` | Standard job processing |
| `mailers` | Email delivery jobs |
| `clock` | Scheduled/recurring tasks from Clockwork |
| `providers` | Third-party provider integrations |
| `webhook` | Webhook delivery jobs |
| `invoices` | Invoice generation and processing |
| `wallets` | (deprecated - jobs migrated to other queues) |
| `integrations` | Integration-related tasks |
| `low_priority` | Non-urgent background tasks |
| `long_running` | Jobs expected to take extended time |

#### Worker Settings

- **Concurrency**: 10 workers (configurable via `SIDEKIQ_CONCURRENCY` env var in production)
- **Timeout**: 25 seconds
- **Retry**: 1 attempt

### Dedicated Workers

Lago supports dedicated workers for specific job types to improve performance and monitoring. When enabled via environment variables, jobs are routed to dedicated queues with their own worker processes, offloading work from the default worker.

#### Architecture Benefits

- **Load distribution**: Removes heavy workloads from the default worker to dedicated workers
- **Performance tuning**: Each worker can be configured independently (concurrency, scaling)
- **Better monitoring**: Isolated metrics per queue type for easier debugging and optimization
- **Horizontal scaling**: Individual worker types can be scaled based on specific needs

#### Configuration

| Environment Variable | Queue Name       | Default Concurrency (Production) | Purpose              |
|----------------------|------------------|----------------------------------|----------------------|
| `SIDEKIQ_ANALYTICS`  | `analytics`      | 10                               | Analytics processing |
| `SIDEKIQ_BILLING`    | `billing`        | 5                                | Billing operations   |
| `SIDEKIQ_CLOCK`      | `clock_worker`   | 5                                | Scheduled tasks      |
| `SIDEKIQ_EVENTS`     | `events`         | 10                               | Event processing     |
| `SIDEKIQ_PAYMENTS`   | `payments`       | 10                               | Payment operations   |
| `SIDEKIQ_PDF`        | `pdfs`           | 10                               | PDF generation       |
| `SIDEKIQ_WEBHOOK`    | `webhook_worker` | 10                               | Webhook delivery     |

#### Queue Routing Logic

Jobs dynamically select their queue based on environment variables. Example from webhook jobs:

```ruby
queue_as do
  if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_WEBHOOK"])
    :webhook_worker  # Dedicated queue with dedicated worker process
  else
    :webhook         # Default worker queue
  end
end
```

**Behavior**:

- When `SIDEKIQ_WEBHOOK=true`:
  - Jobs are sent to the `webhook_worker` queue
  - A dedicated worker process must be started to handle only this queue (check the [scripts directory in the API repository](https://github.com/getlago/lago-api/tree/main/scripts))
  - Load is removed from the default worker
- When `SIDEKIQ_WEBHOOK=false` or unset:
  - Jobs go to the `webhook` queue on the default worker

This pattern is applied across all dedicated worker types, allowing flexible scaling and performance optimization of specific job categories based on workload requirements.

### Worker Flow & Error Handling

#### Job Execution Flow

1. **Job Enqueuing**
   - Main Rails API receives requests and enqueues jobs to appropriate queues
   - Clock process schedules recurring jobs at specified intervals
   - Jobs are stored in Primary Redis (Sidekiq Queue Storage)

2. **Job Processing**
   - Workers poll their assigned queues based on priority order
   - Each worker processes jobs according to its concurrency setting
   - Jobs timeout after 25 seconds by default
   - Workers acknowledge job completion or failure back to Redis

3. **Job States**
   - **Enqueued**: Job is waiting in queue
   - **Processing**: Job is actively being executed by a worker
   - **Completed**: Job finished successfully
   - **Failed**: Job encountered an error
   - **Retrying**: Job is being retried after failure
   - **Dead**: Job exhausted all retries and is moved to dead queue

#### Error Handling & Retry Mechanism

**Default Retry Configuration**:
- **Retry attempts**: We are not retrying jobs by default:
	- `max_retries` set to 0 in `config/initializers/sidekiq.rb`
	- `sidekiq_options retry: 0` in `app/jobs/application_job.rb`.
- **Dead queue**: Failed jobs after exhausting retries are moved to the dead queue for manual inspection

**Error Handling Patterns**:

1. **Transient Errors** (Network issues, temporary service unavailability)
   - Automatically retried according to retry policy
   - Examples: API timeouts, temporary Redis connection loss

2. **Permanent Errors** (Invalid data, business logic failures)
   - May skip retries or fail immediately
   - Logged to Sentry for monitoring
   - Examples: Invalid customer data, missing required records

3. **Timeout Handling**
   - Jobs do not have execution timeout
   - Redis poll has a 5s timeout in `config/initializers/sidekiq.rb`

**Fallback Mechanisms**:

1. **Scheduled Retry Jobs**
   - Clock jobs like "Retry Failed Invoices" (every 15 minutes) and "Retry Generating Subscription Invoices" (hourly) provide secondary retry mechanisms
   - These jobs scan for failed operations and attempt to reprocess them

2. **Dead Queue Processing**
   - Failed jobs in dead queue can be manually retried via Sidekiq web UI
   - Dead jobs are retained for inspection and debugging

3. **Monitoring & Alerting**
   - All jobs tagged with Sentry metadata for error tracking
   - Failed jobs trigger alerts for investigation
   - Queue depth monitoring prevents backlog buildup

**Error Recovery Flow**:
```
Job Fails → Retry #1 (with exponential backoff)
         → Still Fails → Move to Dead Queue
         → Manual Investigation
         → Optional: Manual Retry from Dead Queue
         → OR: Scheduled Retry Job picks up related operation
```

#### Queue Priority & Job Distribution

Workers process jobs from queues in strict priority order:

1. `high_priority` - Critical operations processed first
2. `default` - Standard operations
3. Lower priority queues processed only when higher queues are empty

**Best Practices**:
- Use `high_priority` sparingly for truly urgent operations
- Route long-running jobs to `long_running` queue to prevent blocking
- Enable dedicated workers for high-volume job types (events, webhooks, PDFs)

### Complete Worker Reference

Lago's production deployment includes multiple worker types, each handling specific workloads:

#### Core Workers

| Worker | Queue(s) | Purpose | Required | Scaling Considerations |
|--------|----------|---------|----------|----------------------|
| **Default Worker** (`worker`) | `high_priority`, `default`, `mailers`, `clock`, `providers`, `webhook`, `invoices`, `wallets`, `integrations`, `low_priority`, `long_running` | Handles all job types when dedicated workers are disabled | ✅ Yes | Scale based on overall job volume; start with 3-5 replicas |
| **Analytics Worker** | `analytics` | Processes analytics calculations and reporting | Optional | Enable with `SIDEKIQ_ANALYTICS=true`; scale based on analytics job volume |
| **Billing Worker** | `billing` | Handles billing operations and invoice generation | Recommended | Enable with `SIDEKIQ_BILLING=true`; critical for billing-heavy workloads |
| **Clock Worker** | `clock_worker` | Processes scheduled jobs from Clockwork | Optional | Enable with `SIDEKIQ_CLOCK=true`; single instance usually sufficient |
| **Events Worker** | `events` | Processes incoming usage events | Highly Recommended | Enable with `SIDEKIQ_EVENTS=true`; scale based on event ingestion rate |
| **Payments Worker** | `payments` | Handles payment processing operations | Recommended | Enable with `SIDEKIQ_PAYMENTS=true`; scale based on payment volume |
| **PDF Worker** | `pdfs` | Generates PDF invoices and documents | Highly Recommended | Enable with `SIDEKIQ_PDF=true`; PDF generation is CPU-intensive |
| **Webhook Worker** | `webhook_worker` | Delivers webhooks to customer endpoints | Highly Recommended | Enable with `SIDEKIQ_WEBHOOK=true`; isolate webhook delays from core processing |

#### Specialized Workers

Those workers are not related to Sidekiq and do not pull jobs from Redis. They
are part of the event processing pipeline and use Kafka as their event store.

| Worker | Purpose | Required | Notes |
|--------|---------|----------|-------|
| **Events Consumer Worker** | Consumes events from external queue (e.g., Kafka, SQS) | Conditional | Required if using event streaming architecture |
| **Events Processor Worker** | Processes and aggregates usage events | Conditional | Part of event processing pipeline; handles complex event transformations |

#### Web Services

| Service | Purpose | Required | Notes |
|---------|---------|----------|-------|
| **API** (`api`) | Main Rails API server | ✅ Yes | Handles HTTP requests; scale based on request volume |
| **App** (`app`) | Frontend application | ✅ Yes | Serves the user interface |
| **PDF** (`pdf`) | PDF generation service | Recommended | Repackaged Gotemberg server, it generates PDF and is triggered by the `pdf-worker` process through an API call |

#### Supporting Services

| Service | Purpose | Required |
|---------|---------|----------|
| **Clock Process** (`clock`) | Clockwork scheduler for recurring jobs | ✅ Yes |

### Resource Configuration Guide

Based on production deployment data from high-volume clusters, here are recommended resource configurations:

| Workload    | CPU Request | CPU Limit | Memory Request | Memory Limit | Recommended Replicas | Notes |
|-------------|-------------|-----------|----------------|--------------|----------------------|-------|
| **API**     | 4 cores     | -         | 4Gi            | 4Gi          | 10-30+               | Scale based on request volume; high traffic requires more replicas |
| **App**     | 100m     | -         | 128Mi            | 128Mi          | 2-3               | Only serves static assets through nginx, no need to allocate a lot of resources |
| **Clock Process**    | 100m     | -    | 812Mi          | 812Mi        | 1   | This only enqueues jobs and is not impacted by the volume of requests |
| **Default Worker**   | 1100m    | -    | 2Gi            | 2Gi          | 3-5 | Reduce replicas when using dedicated workers |
| **Analytics Worker** | 1core    | -    | 1100Mi         | 1100Mi       | 3-5 | CPU-intensive analytics calculations |
| **Billing Worker**   | 1100m    | -    | 1100Mi         | 1100Mi       | 3-5 | Critical for billing operations; scale during billing cycles |
| **Events Worker**    | 500m     | -    | 1Gi            | 1Gi          | 2-5 | Scale based on event ingestion rate |
| **Events Consumer Worker**  | 1100m   | - | 1Gi | 1Gi | 1 | Single replica often sufficient with consumer groups |
| **Events Processor Worker** | 2 cores | - | 2Gi | 2Gi | 1 | CPU and memory intensive event processing |
| **PDF Worker**       | 1100m   | - | 1Gi | 1Gi | 1 | Only reads from sidekiq queue and trigger a PDF generation through the PDF deployment (see next) |
| **PDF**              | 2 cores | - | 1Gi | 1Gi | 2-4 | Generates PDF through gotemberg, triggered by worker through HTTP call |
| **Webhook Worker**   | 1100m   | - | 1Gi | 1Gi | 3-10 | Scale based on webhook volume; network I/O bound |
| **Clock Worker**     | 3 cores | - | 8Gi | 8Gi | 1 | High-memory variant for special processing needs |

#### Scaling Guidelines

**When to Scale Up (Increase Resources)**:
- High CPU usage (>80% sustained)
- Memory pressure or OOM kills
- Job processing latency increases
- Queue depth growing consistently

**When to Scale Out (Add Replicas)**:
- Queue backlog building up
- Job wait times increasing
- High request volume to API web
- Peak load periods (billing cycles, month-end)

**Resource Optimization Tips**:

1. **CPU Limits**: Generally avoid CPU limits to prevent throttling; use requests for scheduling
2. **Memory Limits**: Set memory limits to prevent OOM but allow headroom (20-50% above requests)
3. **Dedicated Workers**: Enable dedicated workers for high-volume job types to isolate resource usage
4. **Autoscaling**: Configure Horizontal Pod Autoscaler (HPA) based on:
   - CPU utilization (70-80% target)
   - Queue depth metrics (custom metrics)
   - Memory utilization (60-70% target)

5. **Concurrency Tuning**: Adjust `SIDEKIQ_CONCURRENCY` based on:
   - Available memory (higher concurrency requires more memory)
   - Job characteristics (I/O bound vs CPU bound)
   - Database connection pool size

```

#### Minimal Production Setup

For smaller deployments, minimum required services:

| Service | Replicas | Resources |
|---------|----------|-----------|
| API  | 2 | 1 core, 2Gi RAM |
| Default Worker | 2 | 500m CPU, 1Gi RAM |
| Clock Worker | 1 | 100m CPU, 512Mi RAM |
| App | 1 | 100m CPU, 128Mi RAM |

**Recommended additions as you scale**:
1. Enable PDF Worker first (offload PDF generation)
2. Enable Webhook Worker second (isolate webhook delays)
3. Enable Events Worker third (handle high event volume)
4. Enable Billing Worker for high invoice volume

---

## Clock System

Lago uses Clockwork to schedule recurring jobs. The clock process runs independently and enqueues jobs into Sidekiq at specified intervals.

**Start command**: `bundle exec clockwork ./clock.rb`

### Scheduled Jobs

#### High-Frequency Jobs (Every 1-5 minutes)

| Job | Interval | Description | Configuration |
|-----|----------|-------------|---------------|
| Activate Subscriptions | Every 5 minutes | Activates pending subscriptions | - |
| Refresh Draft Invoices | Every 5 minutes | Updates draft invoice data | - |
| Process Subscription Activity | Configurable (default: 1 minute) | Processes subscription activities | `LAGO_SUBSCRIPTION_ACTIVITY_PROCESSING_INTERVAL_SECONDS` |
| Refresh Lifetime Usages | Configurable (default: 5 minutes) | Refreshes lifetime usage data | `LAGO_LIFETIME_USAGE_REFRESH_INTERVAL_SECONDS`, disable with `LAGO_DISABLE_LIFETIME_USAGE_REFRESH=true` |
| Refresh Wallets Ongoing Balance | Every 5 minutes | Updates wallet balances | Requires cache configuration (`LAGO_MEMCACHE_SERVERS` or `LAGO_REDIS_CACHE_URL`), disable with `LAGO_DISABLE_WALLET_REFRESH=true` |
| Refresh Flagged Subscriptions | Every 1 minute | Refreshes flagged subscriptions | Requires `LAGO_REDIS_STORE_URL` |

#### Hourly Jobs

| Job | Schedule | Description | Configuration |
|-----|----------|-------------|---------------|
| Terminate Ended Subscriptions | At :05 | Ends subscriptions that have reached their end date | - |
| Post-Validate Events | At :05 | Validates events | Disable with `LAGO_DISABLE_EVENTS_VALIDATION=true` |
| Bill Customers | At :10 | Processes subscription billing | - |
| API Keys Track Usage | At :15 | Tracks API key usage metrics | - |
| Compute Daily Usage | At :15 | Calculates daily usage statistics | - |
| Finalize Invoices | At :20 | Finalizes pending invoices | - |
| Mark Invoices as Payment Overdue | At :25 | Updates overdue invoice status | - |
| Terminate Coupons | At :30 | Expires coupons that have reached their end date | - |
| Retry Generating Subscription Invoices | At :30 | Retries failed invoice generation | - |
| Bill Ended Trial Subscriptions | At :35 | Bills subscriptions when trials end | - |
| Terminate Wallets | At :45 | Expires wallets | - |
| Process Dunning Campaigns | At :45 | Executes dunning campaign actions | - |
| Termination Alert | At :50 | Sends alerts for upcoming subscription terminations | - |
| Terminate Expired Wallet Transaction Rules | At :50 | Cleans up expired wallet rules | - |
| Top Up Wallet Interval Credits | At :55 | Adds recurring wallet credits | - |

#### 15-Minute Jobs

| Job | Interval | Description |
|-----|----------|-------------|
| Retry Failed Invoices | Every 15 minutes | Attempts to regenerate failed invoices |
| Retry Inbound Webhooks | Every 15 minutes | Retries failed inbound webhook processing |

#### Daily Jobs

| Job | Schedule | Description |
|-----|----------|-------------|
| Clean Webhooks | At 01:00 | Removes old webhook records |
| Clean Inbound Webhooks | At 01:10 | Removes old inbound webhook records |

### Clock Configuration Notes

- Most jobs run hourly to accommodate customer timezones
- Each job is tagged with Sentry monitoring metadata for error tracking
- Jobs can be conditionally enabled/disabled via environment variables
- All scheduled jobs are enqueued into Sidekiq queues for processing

---

## Redis Architecture

Lago uses three separate Redis instances for different purposes:

### 1. Primary Redis (Sidekiq Queue Storage)

**Configuration**:
- `REDIS_URL` - Connection URI (host, port, database)
- `REDIS_PASSWORD` - Password (separate for security)

**Purpose**: Stores Sidekiq job queues and job data

**Usage**: All Sidekiq workers connect to this Redis instance to fetch and process jobs

### 2. Redis Cache

**Configuration**:
- `LAGO_REDIS_CACHE_URL` - Connection URI
- `LAGO_REDIS_CACHE_PASSWORD` - Password (separate for security)

**Purpose**: Rails application cache store

**Usage**:
- Accessible across all application components (main Rails API, Sidekiq workers, Clock process)
- Used via Rails' standard cache interface (`Rails.cache`)
- Also used directly for low-level caching operations throughout the application
- Stores temporary data like wallet balances, computed values, and other cached information

### 3. Redis Store (Event Processing)

**Configuration**:
- `LAGO_REDIS_STORE_URL` - Connection URI
- `LAGO_REDIS_STORE_PASSWORD` - Password (separate for security)

**Purpose**: Dedicated storage for event-related data and event processing workflows

**Usage**:
- Stores information about incoming events
- Manages event-related worker queues and flags
- Enables features like subscription refresh queue (`ConsumeSubscriptionRefreshedQueueJob`)

### Security Configuration

Lago follows a secure configuration pattern for Redis connections:

- **URI-based configuration**: Each Redis instance uses a `*_URL` environment variable containing the connection details (host, port, database, protocol)
- **Separate password injection**: Passwords are provided via dedicated `*_PASSWORD` environment variables:
  - `REDIS_PASSWORD`
  - `LAGO_REDIS_CACHE_PASSWORD`
  - `LAGO_REDIS_STORE_PASSWORD`

**Benefits**:
- Passwords are kept separate from connection URIs, avoiding exposure in configuration files
- Allows URIs to be non-sensitive configuration while passwords remain secret
- Improves security posture by enabling separate secret management for credentials
- Follows the principle of separating configuration from secrets

> **Architecture Note**: The separation of Redis instances allows for independent scaling and isolation of concerns—queue management, caching, and event processing can be optimized and monitored separately.

---

## Encryption & Security

Lago implements multiple encryption mechanisms to protect sensitive data:

### 1. Active Record Encryption (Database-Level Encryption)

**Configuration**:
- `ENCRYPTION_KEY_DERIVATION_SALT` - Salt for key derivation
- `ENCRYPTION_PRIMARY_KEY` - Primary encryption key

**Purpose**: Encrypts sensitive data at the database row level using Rails' built-in Active Record encryption

**Usage**:
- Integration credentials and configuration
- Payment provider API keys and secrets
- Other sensitive customer data stored in the database

**Mechanism**: Uses Active Record's non-deterministic encryption to secure data at rest (deterministic encryption is not used in Lago)

### 2. HMAC Signing (Organization-Level)

**Configuration**:
- Each organization has its own `hmac_key` stored in the database

**Purpose**: Signs webhook payloads using symmetric cryptography

**Usage**:
- **Webhook signatures**: Signs outgoing webhooks using HMAC-SHA256
- Organization-specific key ensures each customer can verify their own webhooks independently

**Mechanism**:
- HMAC (Hash-based Message Authentication Code) with SHA-256 algorithm
- Signature: `Base64.strict_encode64(OpenSSL::HMAC.digest("sha-256", hmac_key, payload))`
- Included in webhook headers as `X-Lago-Signature`

### 3. Application-Level Signing

#### 3a. SECRET_KEY_BASE (Symmetric Signing)

**Configuration**:
- `SECRET_KEY_BASE` - Master signing key used by Rails

**Purpose**: Signs data for internal application security and secure client communications

**Usage**:
- **Signed URLs**: Creates tamper-proof URLs delivered to clients using Rails' MessageVerifier gem
- **Session management**: Rails session signing and verification
- **Request verification**: Validates the legitimacy of incoming requests, particularly from GraphQL endpoints
- **Internal security**: General application-level signing for secure communications

**Mechanism**:
- HMAC-based signing using Rails' built-in cryptographic primitives
- MessageVerifier ensures URLs and tokens haven't been tampered with

#### 3b. RSA_PRIVATE_KEY (Asymmetric Signing for Webhooks)

**Configuration**:
- `RSA_PRIVATE_KEY` - RSA private key (asymmetric cryptography)

**Purpose**: Signs webhook payloads using JWT with asymmetric cryptography

**Usage**:
- **Webhook signatures only**: Alternative signing method for outgoing webhooks using JWT with RS256 algorithm

**Mechanism**:
- JWT (JSON Web Token) with RS256 (RSA Signature with SHA-256)
- Payload structure: `{ data: webhook_payload, iss: LAGO_API_URL }`
- Recipients can verify using the public key without accessing the private key
- Included in webhook headers as `X-Lago-Signature`

### Webhook Signing Implementation

Webhooks support two configurable signing algorithms (set per `webhook_endpoint`):

#### 1. HMAC Method (`signature_algo: :hmac`)
- Uses organization's `hmac_key`
- Symmetric cryptography
- Simple verification process

#### 2. JWT Method (`signature_algo: :jwt`)
- Uses `RSA_PRIVATE_KEY`
- Asymmetric cryptography
- Allows verification without sharing private key

---

## Usage event

When a user is consuming some resources from the customer a usage event is sent to Lago:

> [!NOTE]
> _A detailed architecture diagram will be added to this section in a future update._


## Billing creation

At least once a month a bill is issued to the users. The flow is as follow

> [!NOTE]
> _A detailed architecture diagram will be added to this section in a future update._

---

## Glossary

**Customer**: An individual or entity that operates within the application, typically representing an organization or team that manages billing, subscriptions, or other business operations. Customers interact with the system to configure, monitor, and manage their own users and related resources.

**User**: An external party or account that is billed or managed by a customer. Users are the end recipients of services, subscriptions, or usage tracked by the application, and are associated with billing events, invoices, and usage records generated by the customer's organization.
