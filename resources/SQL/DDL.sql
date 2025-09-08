CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  output_mode TEXT NOT NULL,
  aggregation TEXT NOT NULL,
  mapping JSONB NOT NULL,
  field_defs JSONB NOT NULL,
  active_version INT,
  status TEXT NOT NULL DEFAULT 'active',
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(app_id, name)
);

CREATE INDEX idx_signatures_app ON signatures(app_id);

CREATE TABLE rulesets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signature_id UUID NOT NULL REFERENCES signatures(id) ON DELETE CASCADE,
  version INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  valid_from TIMESTAMPTZ,
  valid_to   TIMESTAMPTZ,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(signature_id, version)
);

CREATE INDEX idx_rulesets_sig_status ON rulesets(signature_id, status);
CREATE INDEX idx_rulesets_sig_validity ON rulesets(signature_id, valid_from, valid_to);

CREATE TABLE rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ruleset_id UUID NOT NULL REFERENCES rulesets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  priority INT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  condition JSONB NOT NULL,
  effects JSONB NOT NULL,
  stop_on_match BOOLEAN NOT NULL DEFAULT FALSE,
  valid_from TIMESTAMPTZ,
  valid_to   TIMESTAMPTZ,
  tags TEXT[] NOT NULL DEFAULT '{}',
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(ruleset_id, name)
);

CREATE INDEX idx_rules_ruleset_priority ON rules(ruleset_id, priority);
CREATE INDEX idx_rules_ruleset_enabled ON rules(ruleset_id, enabled);
CREATE INDEX idx_rules_ruleset_validity ON rules(ruleset_id, valid_from, valid_to);
CREATE INDEX idx_rules_condition_gin ON rules USING GIN (condition);
CREATE INDEX idx_rules_effects_gin ON rules USING GIN (effects);

-- API keys (opcional, por app)
CREATE TABLE api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  scopes TEXT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active',
  last_used_at TIMESTAMPTZ,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(app_id, name)
);

CREATE INDEX idx_api_keys_app_status ON api_keys(app_id, status);

-- Deployments (opcional)
CREATE TABLE deployments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signature_id UUID NOT NULL REFERENCES signatures(id) ON DELETE CASCADE,
  ruleset_id UUID NOT NULL REFERENCES rulesets(id) ON DELETE RESTRICT,
  version INT NOT NULL,
  activated_by TEXT NOT NULL,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes TEXT
);
CREATE INDEX idx_deployments_sig_time ON deployments(signature_id, activated_at DESC);

-- Audit logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL,
  before JSONB,
  after JSONB,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_time ON audit_logs(inserted_at);