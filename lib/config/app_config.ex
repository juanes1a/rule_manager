defmodule MsEvaluateRules.Config.AppConfig do
  @moduledoc """
   Provides strcut for app-config
  """
    @repo MsEvaluateRules.Infrastructure.Adapters.Repository.Repo


  defstruct [
    :secret,
    :secret_name,
    :env,
    :enable_server,
    :http_port,
    :database,
    :username,
    :password,
    :hostname,
    :port,
    :pool_size
    ]

  def load_config do
    %__MODULE__{
      secret: load(:secret),
      secret_name: load(:secret_name),
      env: load(:env),
      enable_server: load(:enable_server),
      http_port: load(:http_port),
      database: load_repo(:database),
      username: load_repo(:username),
      password: load_repo(:password),
      hostname: load_repo(:hostname),
      port: load_repo(:port),
      pool_size: load_repo(:pool_size)
    }
  end

  defp load(property_name), do: Application.fetch_env!(:ms_evaluate_rules, property_name)

  defp load_repo(property_name) do
    Application.fetch_env!(:ms_evaluate_rules, @repo)[property_name]
  end
end
