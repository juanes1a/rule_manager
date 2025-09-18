defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.RepoTest do
  use ExUnit.Case, async: true
  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  setup do
    # Prepare ETS for SecretManagerAdapter expected table
    case :ets.info(:secret_manager_adapter) do
      :undefined -> :ets.new(:secret_manager_adapter, [:named_table, read_concurrency: true])
      _ -> :ets.delete_all_objects(:secret_manager_adapter)
    end

    :ok
  end

  test "init/2 merges DB credentials from SecretManagerAdapter into config" do
    secret = %{
      database: "db",
      username: "user",
      password: "pass",
      port: 5432,
      hostname: "localhost"
    }

    :ets.insert(:secret_manager_adapter, {:secret, secret})

    assert {:ok, cfg} = Repo.init(:supervisor, [])

    assert Keyword.get(cfg, :database) == "db"
    assert Keyword.get(cfg, :username) == "user"
    assert Keyword.get(cfg, :password) == "pass"
    assert Keyword.get(cfg, :port) == 5432
    assert Keyword.get(cfg, :hostname) == "localhost"
  end

  test "health/0 returns {:ok, true} on successful query" do
    with_mock Postgrex, query: fn _, _, _ -> {:ok, %{}} end do
      assert {:ok, true} == Repo.health()
    end
  end

  test "health/0 returns :error on error and on DBConnection.ConnectionError" do
    with_mock Postgrex, query: fn _, _, _ -> {:error, :boom} end do
      assert :error == Repo.health()
    end

    with_mock Postgrex, query: fn _, _, _ -> raise DBConnection.ConnectionError end do
      assert :error == Repo.health()
    end
  end
end
