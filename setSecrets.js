const fs = require('fs');
const dotenv = require('dotenv');
const { SecretManagerServiceClient } = require('@google-cloud/secret-manager');

const PROJECT_ID = 'atom-pay-dev-be1b';
const SECRET_NAME = 'LAGO_ENV_VARS';

/**
 * Fetches the secrets from Secret Manager and writes them to the .env file
 * @returns {Promise<void>} A promise that resolves when the secrets are written to the .env file
 */
async function setSecrets() {
	const client = new SecretManagerServiceClient();

	try {
		// Access the secret
		const [version] = await client.accessSecretVersion({
			name: `projects/${PROJECT_ID}/secrets/${SECRET_NAME}/versions/latest`
		});

		// Parse the secret payload
		const secrets = JSON.parse(version.payload.data.toString());

		// Replace the newline breaks in the private key
		secrets.LAGO_RSA_PRIVATE_KEY = secrets.LAGO_RSA_PRIVATE_KEY.replace(/\\n/g, '\n');

		let currentEnv = {};

		// If .env file exist, read it
		if (fs.existsSync('.env')) {
			currentEnv = dotenv.parse(fs.readFileSync('.env'));
		}

		// Merge the current environment with the secrets
		const mergedEnv = { ...currentEnv, ...secrets };

		// Write the merged environment to the .env file
		fs.writeFileSync('.env', jsonToEnv(mergedEnv));
	} catch (error) {
		throw new Error(`Error setting secret ${SECRET_NAME}: ${error}`);
	}
}

/**
 * Converts a JSON object to a string of environment variables
 * @param {*} json The JSON object to convert
 * @returns {string} The string of environment variables
 */
function jsonToEnv(json) {
	return Object.entries(json)
		.map(([key, value]) => `${key}="${value}"`)
		.join('\n');
}

// Run the function
setSecrets().catch(console.error);
