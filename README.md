<!-- PROJECT LOGO -->
<p align="center">
  <a href="https://github.com/getlago/lago">
    <img src="https://uploads-ssl.webflow.com/635119506e36baf5c267fecd/635b6df0ee8effaa54c1fa42_banner-open-graph.jpg" alt="Lago">
  </a>

  <h1 align="center">Lago</h1>

  <p align="center">
    The AI-native billing platform
    <br />
    Open-source metering, billing & revenue infrastructure for product-led companies.
    <br />
    <br />
    <a href="https://doc.getlago.com">Docs</a>
    ·
    <a href="https://getlago.com">Website</a>
    ·
    <a href="https://www.getlago.com/slack">Slack</a>
    ·
    <a href="https://github.com/getlago/lago/issues">Issues</a>
    ·
    <a href="https://getlago.canny.io/">Roadmap</a>
  </p>
</p>

<p align="center">
   <a href="https://github.com/getlago/lago/stargazers"><img src="https://img.shields.io/github/stars/getlago/lago" alt="Github Stars"></a>
   <a href="https://github.com/getlago/lago/releases"><img src="https://img.shields.io/github/v/release/getlago/lago" alt="Release"></a>
   <a href="https://github.com/getlago/lago/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-AGPLv3-purple" alt="License"></a>
   <a href="https://www.getlago.com/slack"><img src="https://img.shields.io/badge/Slack-community-%234A154B" alt="Slack"></a>
   <a href="https://www.ycombinator.com"><img src="https://img.shields.io/badge/Backed%20by-Y%20Combinator-%23f26625" alt="YC"></a>
</p>

---

## Trusted by

<p align="center">
  <a href="https://www.getlago.com"><img src="https://getlago.com/customers/paypal.svg" height="30" alt="PayPal" hspace="12"></a>
  <a href="https://www.getlago.com"><img src="https://getlago.com/customers/mistral-ai.svg" height="30" alt="Mistral AI" hspace="12"></a>
  <a href="https://www.getlago.com"><img src="https://getlago.com/customers/groq.svg" height="30" alt="Groq" hspace="12"></a>
  <a href="https://www.getlago.com"><img src="https://getlago.com/customers/synthesia.svg" height="30" alt="Synthesia" hspace="12"></a>
  <a href="https://www.getlago.com"><img src="https://getlago.com/customers/laravel.svg" height="30" alt="Laravel" hspace="12"></a>
</p>

---

## What is Lago?

Lago is the open-source billing platform for usage-based, subscription-based, and hybrid pricing models. If you can track it, you can bill for it.

- **Open-source** — self-host for full control over your data, or use Lago Cloud to get started faster. Either way, the code is transparent
- **Payment-agnostic** — works with Stripe, Adyen, GoCardless, or any payment gateway
- **API-first** — every feature available via REST API
- **SOC 2 Type II certified**

## Features

| Feature | Description |
|---------|-------------|
| **[Usage Metering](https://www.getlago.com/products/metering)** | Real-time event ingestion and aggregation for any pricing dimension |
| **[Billing & Invoicing](https://www.getlago.com/products/invoicing)** | Automated invoice generation for subscriptions, usage, and hybrid plans |
| **[Entitlements](https://www.getlago.com/products/entitlements)** | Feature access management tied directly to your billing plans |
| **[Cash Collection](https://www.getlago.com/products/payments)** | Payment orchestration with dunning, retries, and multi-gateway support |
| **[Revenue Analytics](https://www.getlago.com/products/analytics)** | Cross-stream visibility into MRR, usage trends, and revenue drivers |
| **[Lago Embedded](https://www.getlago.com/products/embedded)** | White-label billing for platforms and marketplaces |
| **[Lago AI](https://www.getlago.com/products/ai)** | AI-powered billing intelligence and MCP server for AI agents |
| **[Integrations](https://doc.getlago.com/integrations/overview)** | NetSuite, Xero, Salesforce, HubSpot, Avalara, AWS/Azure/GCP Marketplace, and more |

## Get Started

### Cloud (fastest)

Start billing in minutes — no infrastructure to manage.

[**Sign up for Lago Cloud**](https://www.getlago.com/pricing) or email hello@getlago.com

### Self-hosted

#### Requirements
- Docker & Docker Compose
- Git

#### Quick start

```bash
# Clone the repo
git clone --depth 1 https://github.com/getlago/lago.git
cd lago

# Generate RSA key
echo "LAGO_RSA_PRIVATE_KEY=\"$(openssl genrsa 2048 | openssl base64 -A)\"" >> .env
source .env

# Start Lago
docker compose up
```

Open http://localhost for the UI. The API is at http://localhost:3000.

#### After an update

```bash
docker compose up
```

#### Configuration

If your server is not at `localhost`, set these in your `.env`:

```
LAGO_API_URL="http://your-server:3000"
LAGO_FRONT_URL="http://your-server"
```

For the full list of environment variables and advanced configuration (S3/GCS storage, SMTP, SSL, dedicated workers for high-volume), see the [self-hosted docs](https://doc.getlago.com/guide/lago-self-hosted/docker#configuration).

#### Find your API key

1. Open the **Developer** section in the sidebar
2. Go to the **API keys** tab
3. Click **Copy**

## Documentation

- [**Getting Started**](https://doc.getlago.com) — Full documentation
- [**API Reference**](https://doc.getlago.com/api-reference) — REST API docs
- [**Billing Templates**](https://getlago.com/docs/templates/introduction) — Reproduce pricing models from Algolia, Segment, Mistral, OpenAI, and more
- [**Development Environment**](./docs/dev_environment.md) — Set up Lago locally for development
- [**Architecture**](./docs/architecture.md) — Technical architecture and flows
- [**Monitoring**](./docs/monitoring.md) — Prometheus metrics and alerting

## SDKs & Client Libraries

| Language | Package |
|----------|---------|
| **Node.js** | [lago-javascript-client](https://github.com/getlago/lago-javascript-client) |
| **Python** | [lago-python-client](https://github.com/getlago/lago-python-client) |
| **Ruby** | [lago-ruby-client](https://github.com/getlago/lago-ruby-client) |
| **Go** | [lago-go-client](https://github.com/getlago/lago-go-client) |

Full OpenAPI spec: [lago-openapi](https://github.com/getlago/lago-openapi)

## Stay up to date

- [Public Roadmap](https://getlago.canny.io/)
- [Changelog](https://doc.getlago.com/changelog)
- [Slack Community](https://www.getlago.com/slack)

## Contributing

We welcome contributions! See our [contributing guide](https://github.com/getlago/lago/blob/main/CONTRIBUTING.md) and the [development environment setup](./docs/dev_environment.md).

Look for issues labeled `beginner` or `help-wanted` to get started.

## License

Distributed under the AGPLv3 License. [Why we chose AGPLv3](https://www.getlago.com/blog/open-source-licensing-and-why-lago-chose-agplv3).

## Analytics & Tracking

Lago tracks basic actions on self-hosted instances by default. No customer PII or financial data is collected. [Learn more or opt out](https://doc.getlago.com/guide/lago-self-hosted/tracking-analytics).
