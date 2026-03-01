# PayTheFly Crypto Payment Integration for Lago

This guide describes how to integrate [PayTheFly](https://paythefly.com) as a crypto payment
provider in your Lago billing setup. PayTheFly enables accepting cryptocurrency payments on
**BSC** (Binance Smart Chain) and **TRON** chains.

## Overview

PayTheFly uses EIP-712 typed structured data signing for payment request authentication.
It supports a redirect-based payment flow where customers are sent to the PayTheFly payment
page to complete on-chain transactions.

## Supported Chains

| Chain | Chain ID    | Token Decimals | Example Token |
|-------|-------------|----------------|---------------|
| BSC   | 56          | 18             | USDT, BUSD    |
| TRON  | 728126428   | 6              | USDT          |

## Environment Variables

Add the following to your `.env` file:

```bash
# PayTheFly Configuration
PAYTHEFLY_PROJECT_ID=your-project-id
PAYTHEFLY_PROJECT_KEY=your-project-key      # For webhook HMAC verification
PAYTHEFLY_PRIVATE_KEY=your-eip712-signer    # For EIP-712 signature generation
PAYTHEFLY_CHAIN_ID=56                        # 56=BSC, 728126428=TRON
PAYTHEFLY_WEBHOOK_URL=https://your-domain.com/webhooks/paythefly
```

> **Security**: Never commit private keys or project keys to version control.
> Always use environment variables or a secrets manager.

## Payment Flow

1. **Create Payment Request**: Your Lago instance generates a PayTheFly payment URL
   with EIP-712 signature parameters
2. **Customer Redirect**: Customer is redirected to PayTheFly payment page:
   ```
   https://pro.paythefly.com/pay?chainId=56&projectId=xxx&amount=0.01&serialNo=xxx&deadline=xxx&signature=0x...&token=0x...
   ```
3. **On-Chain Payment**: Customer completes payment via their crypto wallet
4. **Webhook Notification**: PayTheFly sends a webhook to your Lago instance

### Payment URL Parameters

| Parameter   | Description                                      |
|-------------|--------------------------------------------------|
| `chainId`   | Blockchain chain ID (56 or 728126428)            |
| `projectId` | Your PayTheFly project identifier                |
| `amount`    | Human-readable amount ("0.01"), NOT raw units    |
| `serialNo`  | Unique order/invoice reference                   |
| `deadline`  | Unix timestamp for payment expiry                |
| `signature` | EIP-712 signature (hex with 0x prefix)           |
| `token`     | Token contract address (hex with 0x prefix)      |

> **Important**: The `amount` parameter must be human-readable (e.g., "10.50"),
> not in raw token units (e.g., "10500000000000000000").

## Webhook Configuration

### Webhook Body Format

```json
{
    "data": "{\"serial_no\":\"INV-2024-001\",\"value\":\"10.00\",\"confirmed\":true,\"tx_hash\":\"0xabc...\",\"wallet\":\"0x123...\",\"tx_type\":1}",
    "sign": "hmac_sha256_hex_string",
    "timestamp": 1709312400
}
```

### Signature Verification

PayTheFly webhooks are signed using HMAC-SHA256:

```
signature = HMAC-SHA256(data + "." + timestamp, projectKey)
```

**Important**: Always use timing-safe comparison when verifying signatures to prevent
timing attacks.

### Webhook Payload Fields

The `data` field contains a JSON string with these fields:

| Field        | Type    | Description                           |
|-------------|---------|---------------------------------------|
| `value`     | string  | Payment amount (NOT "amount")         |
| `confirmed` | boolean | Whether payment is confirmed          |
| `serial_no` | string  | Order/invoice serial number           |
| `tx_hash`   | string  | Blockchain transaction hash           |
| `wallet`    | string  | Payer's wallet address                |
| `tx_type`   | integer | 1 = payment, 2 = withdrawal          |

> **Note**: PayTheFly uses `value` (not `amount`) and `confirmed` (not `status`).

### Webhook Response

Your webhook endpoint **must** return a response containing the string `"success"`.
This tells PayTheFly the notification was successfully received.

## EIP-712 Signing Details

PayTheFly uses EIP-712 typed structured data:

### Domain

```
name: "PayTheFlyPro"
version: "1"
```

### PaymentRequest Struct

```
projectId: string
token: address
amount: uint256
serialNo: string
deadline: uint256
```

### Hashing Algorithm

**Critical**: PayTheFly uses **Keccak-256** for hashing.

- ✅ Use Keccak-256 (ethers.js handles this internally)
- ❌ NEVER use SHA3-256 (different padding, different output)
- If your language lacks a native Keccak-256 library, raise an error rather than
  falling back to SHA3-256

## Docker Configuration

When deploying Lago with PayTheFly, add these environment variables to
your `docker-compose.yml`:

```yaml
services:
  api:
    environment:
      PAYTHEFLY_PROJECT_ID: ${PAYTHEFLY_PROJECT_ID}
      PAYTHEFLY_PROJECT_KEY: ${PAYTHEFLY_PROJECT_KEY}
      PAYTHEFLY_PRIVATE_KEY: ${PAYTHEFLY_PRIVATE_KEY}
      PAYTHEFLY_CHAIN_ID: ${PAYTHEFLY_CHAIN_ID:-56}
      PAYTHEFLY_WEBHOOK_URL: ${PAYTHEFLY_WEBHOOK_URL}
```

## Example: Webhook Handler (Ruby)

```ruby
# app/services/payment_providers/paythefly/handle_incoming_webhook_service.rb

module PaymentProviders
  module Paythefly
    class HandleIncomingWebhookService
      def initialize(organization_id:, body:)
        @organization_id = organization_id
        @body = body
      end

      def call
        validate_signature!
        payload = JSON.parse(@body['data'])

        # PayTheFly uses 'value' not 'amount', and 'confirmed' not 'status'
        {
          serial_no: payload['serial_no'],
          value: payload['value'],
          confirmed: payload['confirmed'],
          tx_hash: payload['tx_hash'],
          wallet: payload['wallet'],
          tx_type: payload['tx_type']  # 1=payment, 2=withdrawal
        }
      end

      private

      def validate_signature!
        project_key = ENV.fetch('PAYTHEFLY_PROJECT_KEY')
        message = "#{@body['data']}.#{@body['timestamp']}"
        expected = OpenSSL::HMAC.hexdigest('SHA256', project_key, message)

        # Timing-safe comparison to prevent timing attacks
        unless ActiveSupport::SecurityUtils.secure_compare(expected, @body['sign'])
          raise SecurityError, 'Invalid PayTheFly webhook signature'
        end
      end
    end
  end
end
```

## Troubleshooting

| Issue                          | Solution                                          |
|-------------------------------|---------------------------------------------------|
| Invalid webhook signature     | Verify PAYTHEFLY_PROJECT_KEY matches your project  |
| Wrong hash output             | Ensure using Keccak-256, NOT SHA3-256              |
| Amount mismatch               | Use human-readable amounts (e.g., "10.00")         |
| Payment not confirming        | Check `confirmed` field (not `status`)             |
| Wrong transaction type        | `tx_type=1` is payment, `tx_type=2` is withdrawal  |
| Chain decimal mismatch        | BSC=18 decimals, TRON=6 decimals                   |

## Resources

- [PayTheFly Documentation](https://pro.paythefly.com)
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)
- [Lago Payment Providers](https://doc.getlago.com/integrations/payments/overview)
