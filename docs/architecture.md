# Application Architecture

This document summarizes the application's architecture and core flows.

---

## Table of Contents

- [Global Architecture Diagram](#global-architecture-diagram)
- [System Overview](#system-overview)
- [Worker Architecture](#worker-architecture)
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
| `SIDEKIQ_AI_AGENT`   | `ai_agent`       | 10                               | AI Agent             |

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
