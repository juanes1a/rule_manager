import Config

config :ms_evaluate_rules,
  timezone: "America/Bogota",
  env: :prod,
  http_port: 8083,
  enable_server: true,
  secret: nil,
  secret_name: "secret-name",
  version: "0.0.1",
  custom_metrics_prefix_name: "ms_evaluate_rules"

config :logger,
  level: :error_handler

query_args = ["SET search_path TO public", []]
config :ms_evaluate_rules, MsEvaluateRules.Infrastructure.Adapters.Repository.Repo,
  database: "",
  username: "",
  password: "",
  hostname: "",
  port: "",
  pool_size: 10,
  telemetry_prefix: [:elixir, :repo],
  after_connect: {Postgrex, :query!, query_args}


config :ex_aws, :dynamodb,
  scheme: "",
  host: "",
  port: 8000

config :ms_evaluate_rules,
  rules_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository,
  accumulators_query_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository,
  bucket_query_repository: MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository,
  accumulators_command_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsCommandRepository

# aws
config :ex_aws,
  region: {:system, "AWS_REGION"},
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}, :instance_role],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, "default", 30},
    :instance_role
  ],
  awscli_auth_adapter: ExAws.STS.AuthCache.AssumeRoleWebIdentityAdapter
