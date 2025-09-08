-- Extensión necesaria para digest() (sha256)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Acumulador 1: conteo de transacciones por cliente (buckets diarios)
INSERT INTO accumulators (id, name, description, kind, dimensions, value_field, bucket_gran, retention_days, status, inserted_at, updated_at)
VALUES
  (gen_random_uuid(), 'txn_count',
   'Conteo de transacciones por cliente (ventanas 7d/30d)', 'count',
   '["customer_id"]'::jsonb, NULL, 'day', 90, 'active', now(), now())
ON CONFLICT (name) DO NOTHING;

-- Acumulador 2: suma de montos por cliente (buckets diarios)
INSERT INTO accumulators (id, name, description, kind, dimensions, value_field, bucket_gran, retention_days, status, inserted_at, updated_at)
VALUES
  (gen_random_uuid(), 'sum_amount',
   'Suma de montos por cliente (ventanas 7d/30d)', 'sum',
   '["customer_id"]'::jsonb, 'amount', 'day', 90, 'active', now(), now())
ON CONFLICT (name) DO NOTHING;