#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
ACCOUNT_ID="${ACCOUNT_ID:-11111111-1111-4111-8111-111111111111}"
RUN_ID="${CERT_RUN_ID:-$(date +%s)}"
ORDER_KEY="${ORDER_KEY:-smoke-order-${RUN_ID}}"
POLICY_KEY="${POLICY_KEY:-smoke-policy-${RUN_ID}}"
CORRELATION_ID="${CORRELATION_ID:-smoke-correlation-${RUN_ID}}"

curl -fsS "$API_BASE_URL/ready" >/dev/null

curl -fsS -X POST "$API_BASE_URL/sweep-policies" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $POLICY_KEY" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d "{\"account_id\":\"$ACCOUNT_ID\",\"minimum_cash_balance\":\"100.00\",\"target_product\":\"FYOXX\"}" >/dev/null

order_json="$(curl -fsS -X POST "$API_BASE_URL/sweep-orders" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $ORDER_KEY" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d "{\"account_id\":\"$ACCOUNT_ID\",\"amount\":\"250.00\",\"cash_asset\":\"USD\",\"product_asset\":\"FYOXX\"}")"

order_id="$(printf '%s' "$order_json" | jq -r '.order_id')"
echo "Created order $order_id"

for _ in $(seq 1 90); do
  status="$(curl -fsS "$API_BASE_URL/sweep-orders/$order_id" | jq -r '.status')"
  echo "status=$status"
  if [[ "$status" == "Active" ]]; then
    break
  fi
  sleep 2
done

final_json="$(curl -fsS "$API_BASE_URL/sweep-orders/$order_id")"
printf '%s\n' "$final_json" | jq .
[[ "$(printf '%s' "$final_json" | jq -r '.status')" == "Active" ]]

positions="$(curl -fsS "$API_BASE_URL/accounts/$ACCOUNT_ID/positions")"
printf '%s\n' "$positions" | jq --arg order "$order_id" '[.[] | select(.order_id == $order)]'
[[ "$(printf '%s' "$positions" | jq --arg order "$order_id" '[.[] | select(.order_id == $order)] | length')" == "1" ]]

breaks="$(curl -fsS "$API_BASE_URL/reconciliation-breaks")"
[[ "$(printf '%s' "$breaks" | jq --arg order "$order_id" '[.[] | select(.order_id == $order)] | length')" == "0" ]]

echo "Happy-path smoke passed."
