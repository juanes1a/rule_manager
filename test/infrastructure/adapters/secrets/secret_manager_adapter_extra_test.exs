defmodule MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapterExtraTest do
  use ExUnit.Case, async: true

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Secrets.SecretManagerAdapter, as: SMA

  test "secret_normalize decodes and normalizes json" do
    json = ~s({"username":"u","password":"p","host":"h","port":"5432","dbname":"d"})
    assert {:ok, map} = SMA.secret_normalize(json)
    assert map[:username] == "u"
    assert map[:port] == "5432"
  end

  test "secret_transformation maps fields to repo config" do
    raw = %{username: "u", password: "p", host: "h", port: "5432", dbname: "d"}
    assert {:ok, cfg} = SMA.secret_transformation(raw)
    assert cfg[:username] == "u"
    assert cfg[:hostname] == "h"
    assert cfg[:database] == "d"
  end

  test "get_secret_value happy path and error branches" do
    secret_json = ~s({"username":"u","password":"p","host":"h","port":"5432","dbname":"d"})

    with_mock ExAws, request: fn _, _ -> {:ok, %{"SecretString" => secret_json}} end do
      assert {:ok, m} = SMA.get_secret_value("name", "us-east-1")
      assert m[:username] == "u"
    end

    with_mock ExAws, request: fn _, _ -> {:error, :boom} end do
      assert {:error, :boom} = SMA.get_secret_value("name", "us-east-1")
    end

    with_mock ExAws, request: fn _, _ -> {:unexpected, :tuple} end do
      assert {:unexpected, :tuple} = SMA.get_secret_value("name", "us-east-1")
    end

    with_mock ExAws, request: fn _, _ -> :weird end do
      assert {:error, :weird} = SMA.get_secret_value("name", "us-east-1")
    end
  end
end

