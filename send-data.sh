export DATA=`du -sh .`
echo $DATA

LAGO_URL="http://0.0.0.0:3000" 
API_KEY="5f1c4c7f-9edc-47e9-88a5-266362b58b48"

  curl --location --request POST "$LAGO_URL/api/v1/events" \
--header "Authorization: Bearer $API_KEY" \
--header 'Content-Type: application/json' \
--data-raw '{
  "event": {
    "transaction_id": "trans-id-007",
    "customer_id": "321",
    "code": "000",
    "timestamp": 1650893379,
    "properties": {
      "data-usage": "$DATA"
    }
  }
}'