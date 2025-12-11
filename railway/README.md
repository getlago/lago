# Deploying Lago on Railway

This guide provides comprehensive instructions for deploying Lago on [Railway](https://railway.app).

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Deployment Options](#deployment-options)
- [Quick Start: All-in-One Deployment](#quick-start-all-in-one-deployment)
- [Multi-Service Deployment](#multi-service-deployment)
- [Environment Variables](#environment-variables)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Troubleshooting](#troubleshooting)
- [Scaling](#scaling)

---

## Architecture Overview

Lago consists of several components:

| Component | Technology | Description |
|-----------|------------|-------------|
| **API** | Ruby on Rails | Backend REST API |
| **Frontend** | React/Vite | Web dashboard |
| **Worker** | Sidekiq | Background job processor |
| **Clock** | Clockwork | Scheduled tasks |
| **PDF** | Gotenberg | Invoice PDF generation |
| **Database** | PostgreSQL | Primary data store |
| **Cache** | Redis | Job queue & caching |

---

## Deployment Options

### Option 1: All-in-One (Recommended for getting started)

Single container with all services embedded (PostgreSQL, Redis, Nginx).

**Pros:**
- Simple setup
- Lower cost (single service)
- Quick to deploy

**Cons:**
- Not horizontally scalable
- All services share resources
- Harder to debug

### Option 2: Multi-Service (Recommended for production)

Separate Railway services for each component.

**Pros:**
- Horizontally scalable
- Independent resource allocation
- Better fault isolation
- Professional production setup

**Cons:**
- More complex setup
- Higher cost (multiple services)

---

## Quick Start: All-in-One Deployment

### Step 1: Create Railway Project

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Connect your Lago repository

### Step 2: Configure Build Settings

Railway will automatically detect the `railway.toml` and use Docker.

No additional configuration needed - the root `Dockerfile` handles everything.

### Step 3: Add Persistent Storage

1. Go to your service settings
2. Under **"Volumes"**, add a volume:
   - **Mount Path:** `/data`
   - **Size:** 10GB minimum (adjust based on usage)

### Step 4: Set Environment Variables

In Railway Dashboard, add these variables:

```bash
# Minimal required variables for all-in-one
LAGO_API_URL=https://your-service.up.railway.app:3000
LAGO_FRONT_URL=https://your-service.up.railway.app
LAGO_DISABLE_PDF_GENERATION=true
```

### Step 5: Deploy

Click **"Deploy"** and wait for the build to complete (10-15 minutes first time).

### Step 6: Access Your Instance

Your Lago instance will be available at:
- **Frontend:** `https://your-service.up.railway.app`
- **API:** `https://your-service.up.railway.app:3000`

---

## Multi-Service Deployment

For production deployments, use separate services.

### Step 1: Create Services

Create the following services in your Railway project:

```
lago-project/
├── lago-db         (PostgreSQL plugin)
├── lago-redis      (Redis plugin)
├── lago-api        (Custom - from GitHub)
├── lago-worker     (Custom - from GitHub)
├── lago-clock      (Custom - from GitHub)
├── lago-front      (Custom - from GitHub)
└── lago-pdf        (Docker image)
```

### Step 2: Add Database & Redis

1. Click **"+ New"** > **"Database"** > **"PostgreSQL"**
2. Click **"+ New"** > **"Database"** > **"Redis"**

Railway automatically provides connection URLs.

### Step 3: Deploy API Service

1. Create new service from GitHub
2. Set **Root Directory:** Leave empty (uses root Dockerfile)
3. Add these environment variables:

```bash
# Database (from Railway PostgreSQL plugin)
DATABASE_URL=${{lago-db.DATABASE_URL}}

# Redis (from Railway Redis plugin)
REDIS_URL=${{lago-redis.REDIS_URL}}

# Security keys (generate your own!)
SECRET_KEY_BASE=<generate-with-openssl-rand-hex-64>
LAGO_RSA_PRIVATE_KEY=<generate-rsa-key-base64>
LAGO_ENCRYPTION_PRIMARY_KEY=<generate-with-openssl-rand-hex-32>
LAGO_ENCRYPTION_DETERMINISTIC_KEY=<generate-with-openssl-rand-hex-32>
LAGO_ENCRYPTION_KEY_DERIVATION_SALT=<generate-with-openssl-rand-hex-32>

# URLs
LAGO_API_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
LAGO_FRONT_URL=https://lago-front.up.railway.app
LAGO_PDF_URL=http://lago-pdf.railway.internal:3000

# Rails
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
```

4. Set **Start Command:**
```bash
./scripts/start.api.sh
```

### Step 4: Deploy Worker Service

1. Create new service from same GitHub repo
2. Share the same environment variables as API
3. Set **Start Command:**
```bash
./scripts/start.worker.sh
```

### Step 5: Deploy Clock Service

1. Create new service from same GitHub repo
2. Share the same environment variables as API
3. Set **Start Command:**
```bash
./scripts/start.clock.sh
```

### Step 6: Deploy Frontend

1. Create new service from GitHub
2. Set these environment variables:

```bash
API_URL=https://lago-api.up.railway.app
APP_ENV=production
LAGO_OAUTH_PROXY_URL=https://proxy.getlago.com
```

### Step 7: Deploy PDF Service (Gotenberg)

1. Click **"+ New"** > **"Docker Image"**
2. Set image: `getlago/lago-gotenberg:8`
3. No environment variables needed

---

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/lago` |
| `REDIS_URL` | Redis connection string | `redis://host:6379` |
| `SECRET_KEY_BASE` | Rails secret key | `openssl rand -hex 64` |
| `LAGO_RSA_PRIVATE_KEY` | JWT signing key (base64) | See generation below |
| `LAGO_ENCRYPTION_PRIMARY_KEY` | Encryption key | `openssl rand -hex 32` |
| `LAGO_ENCRYPTION_DETERMINISTIC_KEY` | Deterministic encryption | `openssl rand -hex 32` |
| `LAGO_ENCRYPTION_KEY_DERIVATION_SALT` | Key derivation salt | `openssl rand -hex 32` |
| `LAGO_API_URL` | Public API URL | `https://api.example.com` |
| `LAGO_FRONT_URL` | Public frontend URL | `https://app.example.com` |

### Generating Keys

```bash
# Secret Key Base
openssl rand -hex 64

# RSA Private Key (base64 encoded)
openssl genrsa 2048 | base64 -w 0

# Encryption Keys
openssl rand -hex 32
```

### Optional Variables

See `.env.example` in this directory for complete list of optional variables.

---

## Post-Deployment Configuration

### 1. Create Admin Account

After first deployment, access the frontend and create your account.

Or auto-create via environment variables:

```bash
LAGO_CREATE_ORG=true
LAGO_ORG_NAME=MyCompany
LAGO_ORG_USER_EMAIL=admin@example.com
LAGO_ORG_USER_PASSWORD=SecurePassword123!
```

### 2. Configure Custom Domain

1. Go to Railway service settings
2. Click **"Settings"** > **"Networking"**
3. Add your custom domain
4. Update DNS records as instructed
5. Update `LAGO_API_URL` and `LAGO_FRONT_URL`

### 3. Enable HTTPS

Railway provides automatic HTTPS for all public domains.

### 4. Configure Email (Optional)

Set SMTP variables for email notifications:

```bash
LAGO_FROM_EMAIL=noreply@yourdomain.com
LAGO_SMTP_ADDRESS=smtp.sendgrid.net
LAGO_SMTP_PORT=587
LAGO_SMTP_USERNAME=apikey
LAGO_SMTP_PASSWORD=your-sendgrid-api-key
```

### 5. Configure Storage (Optional)

For production, use external storage:

**AWS S3:**
```bash
LAGO_USE_AWS_S3=true
LAGO_AWS_S3_ACCESS_KEY_ID=your-key
LAGO_AWS_S3_SECRET_ACCESS_KEY=your-secret
LAGO_AWS_S3_REGION=us-east-1
LAGO_AWS_S3_BUCKET=your-bucket
```

**Google Cloud Storage:**
```bash
LAGO_USE_GCS=true
LAGO_GCS_PROJECT=your-project
LAGO_GCS_BUCKET=your-bucket
```

---

## Troubleshooting

### Build Fails: "Railpack could not determine how to build"

**Solution:** Ensure `railway.toml` exists in root with:
```toml
[build]
dockerfilePath = "Dockerfile"
```

### Build Fails: Submodule Clone Error

**Solution:** The Dockerfile clones submodules from GitHub during build. Ensure:
1. GitHub repos are public, OR
2. Add GitHub token as build arg

### Runtime Error: Database Connection Failed

**Solution:**
1. Check `DATABASE_URL` is correct
2. Ensure PostgreSQL service is running
3. Check service networking (use `.railway.internal` for internal URLs)

### Runtime Error: Redis Connection Failed

**Solution:**
1. Check `REDIS_URL` is correct
2. Ensure Redis service is running

### PDF Generation Not Working

**Solution:**
1. Ensure Gotenberg service is running
2. Check `LAGO_PDF_URL` points to correct internal URL
3. Or set `LAGO_DISABLE_PDF_GENERATION=true`

### Memory Issues

**Solution:**
1. Increase service memory in Railway settings
2. Recommended minimums:
   - API: 1GB
   - Worker: 1GB
   - Frontend: 512MB
   - All-in-One: 2GB

### Slow First Request

**Cause:** Rails asset compilation on first request.

**Solution:** This is normal. Subsequent requests will be faster.

---

## Scaling

### Horizontal Scaling (Multi-Service)

1. Go to service settings
2. Under **"Scaling"**, increase replica count
3. Railway automatically load-balances

### Vertical Scaling

1. Go to service settings
2. Under **"Resources"**, adjust:
   - vCPU allocation
   - Memory limit

### Recommended Resources

| Service | CPU | Memory |
|---------|-----|--------|
| API | 1 vCPU | 1-2 GB |
| Worker | 1 vCPU | 1-2 GB |
| Clock | 0.5 vCPU | 512 MB |
| Frontend | 0.5 vCPU | 512 MB |
| PDF | 0.5 vCPU | 512 MB |
| All-in-One | 2 vCPU | 4 GB |

---

## Cost Estimation

Railway pricing (as of 2024):

| Plan | Included | Overage |
|------|----------|---------|
| Hobby | $5/month + usage | Pay per use |
| Pro | $20/user/month | Discounted usage |

**Estimated monthly cost:**

| Deployment | Estimated Cost |
|------------|----------------|
| All-in-One (minimal) | $10-20/month |
| Multi-Service (small) | $30-50/month |
| Multi-Service (production) | $100+/month |

---

## Support

- [Lago Documentation](https://docs.getlago.com)
- [Railway Documentation](https://docs.railway.app)
- [Lago GitHub Issues](https://github.com/getlago/lago/issues)
- [Lago Slack Community](https://getlago.com/slack)
