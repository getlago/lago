#!/bin/bash
# =============================================================================
# Lago Security Keys Generator for Railway
# =============================================================================
# Run this script locally to generate all required security keys
# Then copy the output to your Railway environment variables
# =============================================================================

set -e

echo "=============================================="
echo "  Lago Security Keys Generator"
echo "=============================================="
echo ""

# Generate SECRET_KEY_BASE
SECRET_KEY_BASE=$(openssl rand -hex 64)
echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}"
echo ""

# Generate RSA Private Key (base64 encoded, single line)
LAGO_RSA_PRIVATE_KEY=$(openssl genrsa 2048 2>/dev/null | base64 -w 0)
echo "LAGO_RSA_PRIVATE_KEY=${LAGO_RSA_PRIVATE_KEY}"
echo ""

# Generate Encryption Keys
LAGO_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)
echo "LAGO_ENCRYPTION_PRIMARY_KEY=${LAGO_ENCRYPTION_PRIMARY_KEY}"
echo ""

LAGO_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)
echo "LAGO_ENCRYPTION_DETERMINISTIC_KEY=${LAGO_ENCRYPTION_DETERMINISTIC_KEY}"
echo ""

LAGO_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
echo "LAGO_ENCRYPTION_KEY_DERIVATION_SALT=${LAGO_ENCRYPTION_KEY_DERIVATION_SALT}"
echo ""

echo "=============================================="
echo "  Keys generated successfully!"
echo "=============================================="
echo ""
echo "Copy these values to your Railway dashboard:"
echo "  1. Go to your Railway project"
echo "  2. Click on your service"
echo "  3. Go to 'Variables' tab"
echo "  4. Add each variable above"
echo ""
echo "IMPORTANT: Keep these keys secure and never commit them to git!"
echo ""
