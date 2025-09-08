INSERT INTO signatures (id, app_id, name, output_mode, aggregation, mapping, field_defs, active_version, status, inserted_at, updated_at)
SELECT gen_random_uuid(), a.id, 'kyc_validation', 'boolean', 'sum',
  '{"thresholds":[],"default":{"result":false,"label":"OK"}}'::jsonb,
  '{
     "full_name":   {"type":"string"},
     "doc_number":  {"type":"string"},
     "email":       {"type":"string"},
     "pep":         {"type":"boolean"},
     "customer_id": {"type":"uuid"}
   }'::jsonb,
  1, 'active', now(), now()
FROM applications a WHERE a.name = 'Fraude-Core';

-- Ruleset v1 publicado
INSERT INTO rulesets (id, signature_id, version, status, valid_from, inserted_at, updated_at)
SELECT gen_random_uuid(), s.id, 1, 'published', now(), now(), now()
FROM signatures s JOIN applications a ON a.id = s.app_id
WHERE a.name = 'Fraude-Core' AND s.name = 'kyc_validation';

-- Reglas KYC
-- 1) PEP true -> rechazar inmediato (label y score alto), stop_on_match
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_PEP_TRUE', 10, true,
  '{"field":"pep","op":"=","type":"boolean","value":true}'::jsonb,
  '[{"type":"add_score","value":100},{"type":"set_label","value":"RECHAZAR"}]'::jsonb,
  true, ARRAY['pep'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id
WHERE s.name = 'kyc_validation' AND rs.version = 1;

-- 2) Documento fuera de rango de longitud ( <8 o >12 ) -> revisar
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_DOC_LENGTH_INVALID', 20, true,
  '{"any":[
      {"field":"doc_number","op":"length_lt","type":"string","value":8},
      {"field":"doc_number","op":"length_gt","type":"string","value":12}
   ]}'::jsonb,
  '[{"type":"add_score","value":10},{"type":"set_label","value":"REVISAR"}]'::jsonb,
  false, ARRAY['documento'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id
WHERE s.name = 'kyc_validation' AND rs.version = 1;

-- 3) Email de dominio gratuito -> revisar
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_EMAIL_FREE_DOMAIN', 30, true,
  '{"any":[
      {"field":"email","op":"ends_with","type":"string","value":"@gmail.com"},
      {"field":"email","op":"ends_with","type":"string","value":"@hotmail.com"}
   ]}'::jsonb,
  '[{"type":"add_score","value":5},{"type":"flag","value":"FREE_EMAIL"},{"type":"set_label","value":"REVISAR"}]'::jsonb,
  false, ARRAY['email'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id
WHERE s.name = 'kyc_validation' AND rs.version = 1;

-- 4) Cliente en blacklist (UUID in) -> rechazar
INSERT INTO rules (id, ruleset_id, name, priority, enabled, condition, effects, stop_on_match, tags, inserted_at, updated_at)
SELECT gen_random_uuid(), rs.id, 'R_CUSTOMER_IN_BLACKLIST', 40, true,
  '{"field":"customer_id","op":"in","type":"uuid","value":[
     "11111111-2222-3333-4444-555555555555",
     "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
   ]}'::jsonb,
  '[{"type":"add_score","value":100},{"type":"set_label","value":"RECHAZAR"}]'::jsonb,
  true, ARRAY['blacklist','uuid'], now(), now()
FROM rulesets rs JOIN signatures s ON s.id = rs.signature_id
WHERE s.name = 'kyc_validation' AND rs.version = 1;