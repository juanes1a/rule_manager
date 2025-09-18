#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="http://localhost:8000"
REGION="us-east-1"

export AWS_ACCESS_KEY_ID=dummy
export AWS_SECRET_ACCESS_KEY=dummy
export AWS_DEFAULT_REGION=$REGION

echo ">> Creando tabla acc_buckets..."
aws dynamodb create-table \
  --endpoint-url "$ENDPOINT" \
  --table-name acc_buckets \
  --attribute-definitions \
      AttributeName=pk,AttributeType=S \
      AttributeName=sk,AttributeType=S \
  --key-schema \
      AttributeName=pk,KeyType=HASH \
      AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

echo ">> Habilitando TTL (atributo: ttl)..."
aws dynamodb update-time-to-live \
  --endpoint-url "$ENDPOINT" \
  --table-name acc_buckets \
  --time-to-live-specification "Enabled=true, AttributeName=ttl"

echo ">> Tablas existentes:"
aws dynamodb list-tables --endpoint-url "$ENDPOINT"
echo "OK ✅"
