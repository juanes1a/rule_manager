CREATE EXTENSION IF NOT EXISTS citext;
-- Tabla de definiciones de acumuladores
CREATE TABLE IF NOT EXISTS accumulators (
id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
name citext UNIQUE NOT NULL,
description text,
kind text NOT NULL CHECK (kind IN ('count','sum','max','min','uniq_count')),
dimensions jsonb NOT NULL DEFAULT '[]'::jsonb, -- ["customer_id","country"]
value_field text, -- para SUM; null en COUNT
bucket_gran text NOT NULL CHECK (bucket_gran IN ('minute','hour','day')),
retention_days int NOT NULL DEFAULT 90,
status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
inserted_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now()
);


-- Tabla de buckets (pre-aggregados)
CREATE TABLE IF NOT EXISTS acc_buckets (
accumulator_id uuid NOT NULL REFERENCES accumulators(id) ON DELETE CASCADE,
bucket_start timestamptz NOT NULL,
key_json jsonb NOT NULL, -- {"customer_id":"...","country":"CO"}
key_hash bytea NOT NULL, -- hash(key_json) para índice compacto
value_num numeric NOT NULL DEFAULT 0,
updated_at timestamptz NOT NULL DEFAULT now(),
PRIMARY KEY (accumulator_id, bucket_start, key_hash)
);


-- Índices
CREATE INDEX IF NOT EXISTS acc_buckets_acc_time_idx ON acc_buckets (accumulator_id, bucket_start DESC);
CREATE INDEX IF NOT EXISTS acc_buckets_gin_key ON acc_buckets USING GIN (key_json jsonb_path_ops);