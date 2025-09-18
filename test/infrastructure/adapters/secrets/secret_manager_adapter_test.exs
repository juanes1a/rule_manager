defmodule MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapterTest do
  use ExUnit.Case, async: false
  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapter
  alias MsEvaluateRules.Config.AppConfig

  setup do
    # Ensure ConfigHolder ETS table exists
    if :ets.info(:ms_evaluate_rules_config) == :undefined do
      :ets.new(:ms_evaluate_rules_config, [:public, :named_table, read_concurrency: true])
    end
    :ets.delete_all_objects(:ms_evaluate_rules_config)

    # Ensure SecretManagerAdapter ETS is clean if exists
    case :ets.info(:secret_manager_adapter) do
      :undefined -> :ok
      _ -> :ets.delete(:secret_manager_adapter)
    end

    :ok
  end

  test "init(false) stores and returns local config in non-prod env" do
    config = %AppConfig{env: :test, secret_name: "name", enable_server: false}
    :ets.insert(:ms_evaluate_rules_config, {:config, config})

    assert {:ok, true} = SecretManagerAdapter.init(false)

    # get_secret reads from ETS
    assert SecretManagerAdapter.get_secret() == config
  end

  test "get_secret returns error when not present" do
    # ensure table exists but no secret inserted
    case :ets.info(:secret_manager_adapter) do
      :undefined -> :ets.new(:secret_manager_adapter, [:named_table, read_concurrency: true])
      _ -> :ets.delete_all_objects(:secret_manager_adapter)
    end

    assert {:error, :no_secret_found} = SecretManagerAdapter.get_secret()
  end

  test "init(true) and handle_info(:get_secret, _) store local config into ETS in non-prod" do
    config = %AppConfig{env: :test, secret_name: "name", enable_server: false}
    :ets.insert(:ms_evaluate_rules_config, {:config, config})

    assert {:ok, nil} = SecretManagerAdapter.init(true)

    # After handle_info, ETS should contain the secret config
    assert {:noreply, _} = SecretManagerAdapter.handle_info(:get_secret, nil)
    assert SecretManagerAdapter.get_secret() == config
  end

  test "start_link/1 initializes ETS and stores secret on non-prod env" do
    config = %AppConfig{env: :test, secret_name: "name", enable_server: false}
    :ets.insert(:ms_evaluate_rules_config, {:config, config})

    assert {:ok, pid} = SecretManagerAdapter.start_link(false)
    assert Process.alive?(pid)
    # Should have inserted secret immediately in init(false)
    assert SecretManagerAdapter.get_secret() == config
    GenServer.stop(pid)
  end

  test "start_link/1 with async true starts process" do
    config = %AppConfig{env: :test, secret_name: "name", enable_server: false}
    :ets.insert(:ms_evaluate_rules_config, {:config, config})

    assert {:ok, pid} = SecretManagerAdapter.start_link(true)
    assert Process.alive?(pid)
    GenServer.stop(pid)
  end

end
