#!/bin/bash

# Install npm packages
npm install @google-cloud/secret-manager dotenv

# Run setSecrets.js to set the secrets in the environment
node setSecrets.js

# Run Docker Compose to start Lago
docker-compose up -d