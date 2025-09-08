-- ============================================================
-- Firma 2: FX Risk (score) – app: Pagos-Internacionales
-- ============================================================
INSERT INTO signatures (id, app_id, name, output_mode, aggregation, mapping, field_defs, active_version, status, inserted_at, updated_at)
SELECT gen_random_uuid(), a.id, 'fx_risk', 'score', 'sum',
  '{
     "thresholds": [
       {"gte": 80, "result": true,  "label": "RECHAZAR"},
       {"gte": 40, "result": false, "label": "REVISAR"}
     ],
     "default": {"result": false, "label": "APROBAR"}
   }'::jsonb,
  '{
     "amount":     {"type":"number"},
     "fx_rate":    {"type":"decimal"},
     "txn_at":     {"type":"datetime"},
     "corridor":   {"type":"string"},
     "is_corporate":{"type":"boolean"}
   }'::jsonb,
  1, 'active', now(), now()
FROM applications a WHERE a.name = 'Pagos-Internacionales';

INSERT INTO rulesets (id, signature_id, version, status, valid_from, inserted_at, updated_at)
SELECT gen_random_uuid(), s.id, 1, 'published', now(), now(), now()
FROM signatures s JOIN applications a ON a.id = s.app_id
WHERE a.name = 'Pagos-Internacionales' AND s.name = 'fx_risk';

-- Reglas FX Risk
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_HIGH_FX_RATE', 10, true,
  '{"field":"fx_rate","op":">","type":"decimal","value":"4.2"}'::jsonb,
  '[{"type":"add_score","value":40}]'::jsonb,
  false, ARRAY['decimal'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'fx_risk' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_RECENT_TXN', 20, true,
  '{"field":"txn_at","op":">=","type":"datetime","value":{"fn":"hours_ago","args":[2]}}'::jsonb,
  '[{"type":"add_score","value":10}]'::jsonb,
  false, ARRAY['datetime'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'fx_risk' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_CORRIDOR_RISKY', 30, true,
  '{"field":"corridor","op":"in","type":"string","value":["VE-CO","CO-VE"]}'::jsonb,
  '[{"type":"add_score","value":30}]'::jsonb,
  false, ARRAY['corridor'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'fx_risk' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_AMOUNT_LARGE', 40, true,
  '{"field":"amount","op":">=","type":"number","value":100000}'::jsonb,
  '[{"type":"add_score","value":50}]'::jsonb,
  false, ARRAY['amount'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'fx_risk' AND rs.version = 1;

-- Etiqueta informativa si es corporativo (no afecta score)
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_CORPORATE_INFO', 50, true,
  '{"field":"is_corporate","op":"=","type":"boolean","value":true}'::jsonb,
  '[{"type":"set_label","value":"CORP"},{"type":"flag","value":"CORPORATE"}]'::jsonb,
  false, ARRAY['corp'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'fx_risk' AND rs.version = 1;


-- =====================================================
-- Firma 3: Promo Eligibility (string) – app: Fraude-Core
-- =====================================================
INSERT INTO signatures (id, app_id, name, output_mode, aggregation, mapping, field_defs, active_version, status, inserted_at, updated_at)
SELECT gen_random_uuid(), a.id, 'promo_eligibility', 'string', 'sum',
  '{"thresholds":[],"default":{"result":false,"label":"NOT_ELIGIBLE"}}'::jsonb,
  '{
     "segment":      {"type":"string"},
     "signup_date":  {"type":"date"},
     "has_debt":     {"type":"boolean"},
     "emails_count": {"type":"number"},
     "referrer":     {"type":"string"}
   }'::jsonb,
  1, 'active', now(), now()
FROM applications a WHERE a.name = 'Fraude-Core';

INSERT INTO rulesets (id, signature_id, version, status, valid_from, inserted_at, updated_at)
SELECT gen_random_uuid(), s.id, 1, 'published', now(), now(), now()
FROM signatures s JOIN applications a ON a.id = s.app_id
WHERE a.name = 'Fraude-Core' AND s.name = 'promo_eligibility';

-- Reglas Promo
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_SEGMENT_GOLD', 10, true,
  '{"field":"segment","op":"=","type":"string","value":"GOLD"}'::jsonb,
  '[{"type":"set_label","value":"ELIGIBLE"}]'::jsonb,
  false, ARRAY['segment'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'promo_eligibility' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_NEW_USER_30D', 20, true,
  '{"field":"signup_date","op":">=","type":"date","value":{"fn":"days_ago","args":[30]}}'::jsonb,
  '[{"type":"set_label","value":"ELIGIBLE"}]'::jsonb,
  false, ARRAY['antiguedad'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'promo_eligibility' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_DEBT', 30, true,
  '{"field":"has_debt","op":"=","type":"boolean","value":true}'::jsonb,
  '[{"type":"set_label","value":"MANUAL_REVIEW"}]'::jsonb,
  false, ARRAY['riesgo'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'promo_eligibility' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_SPAMMY', 40, true,
  '{"field":"emails_count","op":">","type":"number","value":5}'::jsonb,
  '[{"type":"set_label","value":"MANUAL_REVIEW"}]'::jsonb,
  false, ARRAY['comms'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'promo_eligibility' AND rs.version = 1;

INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_REFERRER_MISSING', 50, true,
  '{"field":"referrer","op":"missing","type":"string"}'::jsonb,
  '[{"type":"set_label","value":"NOT_ELIGIBLE"}]'::jsonb,
  false, ARRAY['missing'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id WHERE s.name = 'promo_eligibility' AND rs.version = 1;