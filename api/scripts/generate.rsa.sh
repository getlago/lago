#!/bin/bash
set -e

# Path where RSA keys will be stored inside the container

KEY_DIR="./config/keys"
PRIVATE_KEY="$KEY_DIR/private.pem"
PUBLIC_KEY="$KEY_DIR/public.pem"

# Create the keys directory if it doesn't exist
mkdir -p "$KEY_DIR"

# Generate RSA key pair if not already generated
if [ ! -f "$PRIVATE_KEY" ]; then
    echo "Generating RSA key pair..."
    openssl genpkey -algorithm RSA -out "$PRIVATE_KEY"
    openssl rsa -pubout -in "$PRIVATE_KEY" -out "$PUBLIC_KEY"
    echo "RSA keys generated at $KEY_DIR"
fi

# Set permissions
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"
