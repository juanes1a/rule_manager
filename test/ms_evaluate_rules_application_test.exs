defmodule MsEvaluateRules.ApplicationTest do
  use ExUnit.Case
  doctest MsEvaluateRules.Application
  alias MsEvaluateRules.Config.{ConfigHolder, AppConfig}

  test "test childrens" do
    assert MsEvaluateRules.Application.env_children(:test, %AppConfig{}) == []
  end

  test "env_children/2 returns secrets and repo on non-test env" do
    children = MsEvaluateRules.Application.env_children(:dev, %AppConfig{})
    assert Enum.any?(children, fn {mod, _} -> mod == MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapter end)
    assert Enum.any?(children, fn {mod, _} -> mod == MsEvaluateRules.Infrastructure.Adapters.Repository.Repo end)
  end

  setup do
    if :ets.info(:ms_evaluate_rules_config) == :undefined do
      :ets.new(:ms_evaluate_rules_config, [:public, :named_table, read_concurrency: true])
    end

    :ets.delete_all_objects(:ms_evaluate_rules_config)
    :ok
  end

  test "conf/0 returns the current config when it exists" do
    config = %AppConfig{env: :test, enable_server: true, http_port: 8083}

    :ets.insert(:ms_evaluate_rules_config, {:config, config})

    assert ConfigHolder.conf() == config
  end

  test "get!/1 raises an error when the key does not exist" do
    :ets.delete_all_objects(:ms_evaluate_rules_config)

    assert_raise RuntimeError, "Config with key :nonexistent_key not found", fn ->
      ConfigHolder.get!(:nonexistent_key)
    end
  end
end
