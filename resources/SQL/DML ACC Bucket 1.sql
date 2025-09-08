WITH
cust AS (
  SELECT jsonb_build_object('customer_id','11111111-2222-3333-4444-555555555555') AS key_json
  UNION ALL
  SELECT jsonb_build_object('customer_id','aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
),
days AS (
  SELECT date_trunc('day', now()) - (i || ' days')::interval AS bucket_start, i
  FROM generate_series(0, 6) AS g(i)
)
INSERT INTO acc_buckets (accumulator_id, bucket_start, key_json, key_hash, value_num, updated_at)
SELECT
  a.id,
  d.bucket_start,
  c.key_json,
  digest(c.key_json::text, 'sha256') AS key_hash,
  CASE
    WHEN (c.key_json->>'customer_id') = '11111111-2222-3333-4444-555555555555' THEN 1
    ELSE 2
  END::numeric AS value_num,
  now()
FROM accumulators a
JOIN days d ON TRUE
JOIN cust c ON TRUE
WHERE a.name = 'txn_count'
ON CONFLICT (accumulator_id, bucket_start, key_hash)
DO UPDATE SET
  value_num = acc_buckets.value_num + EXCLUDED.value_num,
  updated_at = now();
