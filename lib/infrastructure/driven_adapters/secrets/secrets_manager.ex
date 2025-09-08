defmodule MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapter do
  use GenServer

  alias MsEvaluateRules.Config.{ConfigHolder, AppConfig}
  alias MsEvaluateRules.Utils.DataTypeUtils
  require Logger
  @compile if Mix.env() == :test, do: :export_all

  def start_link(async_init) do
    GenServer.start_link(__MODULE__, async_init, name: __MODULE__)
  end

  def init(true = _async_init) do
    create_ets()
    send(self(), :get_secret)
    {:ok, nil}
  end

  def init(_async_init) do
    create_ets()
    {:ok, get_initial_secret()}
  end

  defp create_ets do
    :ets.new(:secret_manager_adapter, [:named_table, read_concurrency: true])
  end

  def handle_info(:get_secret, _args) do
    {:noreply, get_initial_secret()}
  end

  defp get_initial_secret() do
    if Application.get_env(:ms_evaluate_rules, :env, :prod) != :prod do
      Logger.info("Cargando credenciales de bases de datos, y lo requerido en los headers para las solicitudes a los servicios desde local")
      join_secrets = ConfigHolder.conf()
      :ets.insert(:secret_manager_adapter, {:secret, join_secrets})
    else
      Logger.info("Cargando credenciales de bases de datos, y lo requerido en los headers para las solicitudes a los servicios desde AWS")

      secret_name = ConfigHolder.conf().secret_name
      region = ConfigHolder.conf().region

      with {:ok, db_secret} <- get_secret_value(secret_name, region),
            {:ok, db_credentials} <- secret_transformation(db_secret) do
        join_secrets = [db_credentials]
          |> Enum.reduce(&Map.merge/2)

        :ets.insert(:secret_manager_adapter, {:secret, join_secrets})
        join_secrets
      else
        error ->
          Logger.error("Error obteniendo credenciales para BBDD y servicios de los secretos: #{inspect(error)}")
          error
      end
    end
  end

  defp secret_normalize(secret_value) do
    {
      :ok,
      secret_value
      |> Poison.decode!()
      |> DataTypeUtils.normalize()
    }
  end

  defp secret_transformation(
         %{username: username, password: password,
          host: host, port: port, dbname: dbname}
       ) do
    {
      :ok,
      %{
        username: username,
        password: password,
        hostname: host,
        port: port,
        database: dbname
      }
    }
  end

  def get_secret() do
    case :ets.lookup(:secret_manager_adapter, :secret) do
      [{_, secret}] -> secret |> IO.inspect()
      _ -> {:error, :no_secret_found}
    end
  end

  defp get_secret_value(secret_name, region) do
    ExAws.SecretsManager.get_secret_value(secret_name)
    |> ExAws.request(region: region)
    |> case do
      {:ok, %{"SecretString" => secret_string}} ->
        secret_string
        |> secret_normalize()

      {code, rs} ->
        Logger.error("Error inesperado obteniendo un secreto: #{inspect({code, rs})}")
        {code, rs}

      no_expected ->
        Logger.error("Error inesperado obteniendo un secreto: #{inspect(no_expected)}")
        {:error, no_expected}
    end
  end

end
