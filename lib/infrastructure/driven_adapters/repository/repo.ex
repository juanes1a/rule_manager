defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Repo do
  alias MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapter

  use Ecto.Repo,
    otp_app: :ms_evaluate_rules,
    adapter: Ecto.Adapters.Postgres

  require Logger

  def init(_type, config) do
    %{
      database: database,
      username: username,
      password: password,
      port: port,
      hostname: host
    } = SecretManagerAdapter.get_secret()

    config =
      config
      |> Keyword.put(:hostname, host)
      |> Keyword.put(:port, port)
      |> Keyword.put(:username, username)
      |> Keyword.put(:password, password)
      |> Keyword.put(:database, database)

    {:ok, config}
  end

  def health() do
    try do
      case Postgrex.query(__MODULE__, "select 1", []) do
        {:ok, _res} -> {:ok, true}
        _error -> :error
      end
    rescue
      DBConnection.ConnectionError -> :error
    end
  end
end
