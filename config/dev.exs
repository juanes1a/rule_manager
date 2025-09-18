import Config

config :ms_evaluate_rules, timezone: "America/Bogota"
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
config :tzdata, :autoupdate, :disabled

config :ms_evaluate_rules,
  timezone: "America/Bogota",
  env: :dev,
  http_port: 8083,
  enable_server: true,
  secret: nil,
  secret_name: "secret-name",
  version: "0.0.1",
  custom_metrics_prefix_name: "ms_evaluate_rules_local"

config :logger,
  level: :debug

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

config :ex_aws, :dynamodb,
  scheme: "http://",
  host: "localhost",
  port: 8000

config :ms_evaluate_rules,
  rules_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository,
  accumulators_query_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository,
  bucket_query_repository: MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository,
  accumulators_command_repository: MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsCommandRepository

# aws
config :ex_aws,
  json_codec: Jason,
  region: "us-east-1",
  access_key_id: "dummy",
  secret_access_key: "dummy"

# to override aws endpoint for localstack
# config :ex_aws, :secretsmanager, # change for specific service
#  scheme: "http://",
#  host: "localhost",
#  port: 4566
