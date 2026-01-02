# Lago on Railway - Quick Start Guide

## 5-Minute Deployment

### Step 1: Fork & Connect

1. Fork this repository to your GitHub account
2. Go to [railway.app](https://railway.app) and create a new project
3. Select "Deploy from GitHub repo"
4. Connect your forked repository

### Step 2: Add Database Services

Click "+ New" and add:
- **PostgreSQL** (Railway plugin)
- **Redis** (Railway plugin)

### Step 3: Generate Security Keys

Run locally:
```bash
chmod +x railway/generate-keys.sh
./railway/generate-keys.sh
```

Copy the output values.

### Step 4: Configure Variables

In Railway Dashboard, add these variables to your main service:

```bash
# From Railway plugins (use variable references)
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}

# From generate-keys.sh output
SECRET_KEY_BASE=<paste-value>
LAGO_RSA_PRIVATE_KEY=<paste-value>
LAGO_ENCRYPTION_PRIMARY_KEY=<paste-value>
LAGO_ENCRYPTION_DETERMINISTIC_KEY=<paste-value>
LAGO_ENCRYPTION_KEY_DERIVATION_SALT=<paste-value>

# URLs (update after deployment)
LAGO_API_URL=https://<your-domain>.up.railway.app
LAGO_FRONT_URL=https://<your-domain>.up.railway.app
API_URL=https://<your-domain>.up.railway.app

# Disable PDF for now (optional)
LAGO_DISABLE_PDF_GENERATION=true

# Use Railway-optimized runner
USE_RAILWAY_RUNNER=true
USE_EMBEDDED_DB=false
USE_EMBEDDED_REDIS=false
```

### Step 5: Add Volume (Optional but Recommended)

1. Go to service Settings
2. Add Volume with mount path: `/data`

### Step 6: Deploy

Click "Deploy" and wait 10-15 minutes for the first build.

### Step 7: Access Lago

Your instance is available at:
```
https://<your-service>.up.railway.app
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails | Check `railway.toml` exists at root |
| DB connection error | Verify `DATABASE_URL` variable reference |
| Redis error | Verify `REDIS_URL` variable reference |
| Slow startup | Normal for first request - wait 30s |

---

## Need More Help?

See the full documentation: [railway/README.md](./README.md)
