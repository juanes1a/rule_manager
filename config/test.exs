import Config

config :ms_evaluate_rules,
  timezone: "America/Bogota",
  env: :test,
  http_port: 8083,
  enable_server: false,
  secret: nil,
  secret_name: "secret-name",
  version: "0.0.1",
  custom_metrics_prefix_name: "ms_evaluate_rules_test"

config :logger,
  level: :info

query_args = ["SET search_path TO public", []]
config :ms_evaluate_rules,
MsEvaluateRules.Infrastructure.Adapters.Repository.Repo,
  database: "postgres",
  username: "postgres",
  password: "12345",
  hostname: "localhost",
  port: "5432",
  pool_size: 10,
  telemetry_prefix: [:elixir, :repo],
  after_connect: {Postgrex, :query!, query_args}

config :ms_evaluate_rules,
  rules_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository

# Para pruebas que usan AccumulatorUseCase (compile_env)
config :ms_evaluate_rules,
  rules_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository,
  accumulators_query_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository,
  bucket_query_repository: MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository,
  accumulators_command_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsCommandRepository

# Nota: se eliminó la configuración de :junit_formatter porque la dependencia no está incluida.

config :elixir_structure_manager,
  sonar_base_folder: ""

# aws
config :ex_aws,
  json_codec: Jason,
  region: "us-east-1",
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}, :instance_role],
  secret_access_key: [
    {:system, "AWS_SECRET_ACCESS_KEY"},
    {:awscli, "default", 30},
    :instance_role
  ],
  awscli_auth_adapter: ExAws.STS.AuthCache.AssumeRoleCredentialsAdapter

# to override aws endpoint for localstack
# config :ex_aws, :secretsmanager, # change for specific service
#  scheme: "http://",
#  host: "localhost",
#  port: 4566

# Explicit Dynamo endpoint for local testing
config :ex_aws, :dynamodb,
  scheme: "http://",
  host: "localhost",
  port: 8000
