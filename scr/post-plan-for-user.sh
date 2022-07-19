LAGO_URL="http://0.0.0.0:3000"
API_KEY="877a338f-4e15-4907-b4e3-990232125fe5"

curl --location --request POST "$LAGO_URL/api/v1/subscriptions" \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data-raw '{
    "subscription": {
      "customer_id": "666",
      "plan_code": "999"
    }
  }'
  