-- Última vez visto (recencia exacta) por acumulador y clave
CREATE TABLE IF NOT EXISTS acc_last_seen (
  accumulator_id UUID NOT NULL REFERENCES accumulators(id) ON DELETE CASCADE,
  key_json       JSONB NOT NULL,       -- dimensiones normalizadas ({"customer_id":"..."} ...)
  key_hash       BYTEA NOT NULL,       -- sha256 de key_json canónico
  last_at        TIMESTAMPTZ NOT NULL, -- timestamp del último evento observado
  count          BIGINT NOT NULL DEFAULT 0,  -- total de eventos observados para esa clave
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (accumulator_id, key_hash)
);

-- Búsquedas por dimensiones (útil para auditoría/diagnóstico)
CREATE INDEX IF NOT EXISTS acc_last_seen_keyjson_gin
  ON acc_last_seen USING GIN (key_json jsonb_path_ops);

-- (Opcional) para consultas por recencia
CREATE INDEX IF NOT EXISTS acc_last_seen_last_at_idx
  ON acc_last_seen (last_at DESC);

-- (Opcional) si haces housekeeping por updated_at
CREATE INDEX IF NOT EXISTS acc_last_seen_updated_at_idx
  ON acc_last_seen (updated_at DESC);