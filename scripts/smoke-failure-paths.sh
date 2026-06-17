#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
ACCOUNT_ID="${ACCOUNT_ID:-22222222-2222-4222-8222-222222222222}"
RUN_ID="${CERT_RUN_ID:-$(date +%s)}"
KEY="duplicate-demo-key-${RUN_ID}"
CORRELATION_ID="failure-smoke-${RUN_ID}"

curl -fsS "$API_BASE_URL/ready" >/dev/null

first="$(curl -fsS -X POST "$API_BASE_URL/sweep-orders" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $KEY" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d "{\"account_id\":\"$ACCOUNT_ID\",\"amount\":\"125.00\",\"cash_asset\":\"USD\",\"product_asset\":\"FYOXX\"}")"
second="$(curl -fsS -X POST "$API_BASE_URL/sweep-orders" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $KEY" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d "{\"account_id\":\"$ACCOUNT_ID\",\"amount\":\"125.00\",\"cash_asset\":\"USD\",\"product_asset\":\"FYOXX\"}")"
[[ "$(printf '%s' "$first" | jq -r '.order_id')" == "$(printf '%s' "$second" | jq -r '.order_id')" ]]

yield_response="$(curl -sS -o /tmp/no-yield-response.json -w '%{http_code}' -X POST "$API_BASE_URL/dev/attempt-fidd-yield" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: no-yield-${RUN_ID}" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d "{\"account_id\":\"$ACCOUNT_ID\",\"amount\":\"1.00\"}")"
[[ "$yield_response" == "422" ]]

curl -fsS -X POST "$API_BASE_URL/dev/failure-injections/reconciliation-mismatch" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: mismatch-${RUN_ID}" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d '{"enabled":true}' >/dev/null

mismatch="$(curl -fsS -X POST "$API_BASE_URL/sweep-orders" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: mismatch-order-${RUN_ID}" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d "{\"account_id\":\"$ACCOUNT_ID\",\"amount\":\"175.00\",\"cash_asset\":\"USD\",\"product_asset\":\"FYOXX\"}")"
mismatch_id="$(printf '%s' "$mismatch" | jq -r '.order_id')"

for _ in $(seq 1 90); do
  count="$(curl -fsS "$API_BASE_URL/reconciliation-breaks" | jq --arg order "$mismatch_id" '[.[] | select(.order_id == $order)] | length')"
  if [[ "$count" != "0" ]]; then
    break
  fi
  sleep 2
done
[[ "$(curl -fsS "$API_BASE_URL/reconciliation-breaks" | jq --arg order "$mismatch_id" '[.[] | select(.order_id == $order)] | length')" != "0" ]]

curl -fsS -X POST "$API_BASE_URL/dev/failure-injections/reconciliation-mismatch" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: mismatch-off-${RUN_ID}" \
  -H "Correlation-Id: $CORRELATION_ID" \
  -d '{"enabled":false}' >/dev/null

echo "Failure-path smoke passed."
