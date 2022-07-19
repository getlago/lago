export DATA=$(du -sh . | numfmt --from=auto | tr -d ' .')

LAGO_URL="http://0.0.0.0:3000"
API_KEY="877a338f-4e15-4907-b4e3-990232125fe5"

curl --location --request POST "$LAGO_URL/api/v1/events" \
    --header "Authorization: Bearer $API_KEY" \
    --header 'Content-Type: application/json' \
    --data-raw '{
  "event": {
    "transaction_id": "trans-id-009",
    "customer_id": "666",
    "code": "123",
    "timestamp": 1650893379,
    "properties": {
      "data-used": "'"$DATA"'"
    }
  }
}'
