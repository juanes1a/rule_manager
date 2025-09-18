defmodule MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketCommandRepositoryTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketCommandRepository, as: BCR

  @table "tbl"
  @acc "acc"
  @key <<0x01, 0x02, 0x03>>

  test "add!/6 updates sum by default and returns ok" do
    ts = ~N[2023-10-10 12:34:56]

    with_mock ExAws, request!: fn _op -> :ok end do
      assert {:ok, true} = BCR.add!(@table, @acc, @key, ts, 2.5)
    end
  end

  test "add!/6 supports kind count" do
    ts = ~N[2023-10-10 12:34:56]
    with_mock ExAws, request!: fn _op -> :ok end do
      assert {:ok, true} = BCR.add!(@table, @acc, @key, ts, 1, "count")
    end
  end

  test "max!/6 happy path" do
    ts = ~N[2023-10-10 12:34:56]
    with_mock ExAws, request!: fn _op -> :ok end do
      assert {:ok, true} = BCR.max!(@table, @acc, @key, ts, 10.0)
    end
  end

  test "max!/6 swallows ConditionalCheckFailed exception" do
    ts = ~N[2023-10-10 12:34:56]

    with_mock ExAws, request!: fn _op ->
      raise ExAws.Error, message: "ConditionalCheckFailed: condition not met"
    end do
      assert {:ok, true} = BCR.max!(@table, @acc, @key, ts, 10.0)
    end
  end

  test "max!/6 reraises unexpected ExAws.Error" do
    ts = ~N[2023-10-10 12:34:56]

    with_mock ExAws, request!: fn _op ->
      raise ExAws.Error, message: "SomeOtherError: boom"
    end do
      assert_raise ExAws.Error, fn -> BCR.max!(@table, @acc, @key, ts, 10.0) end
    end
  end

  test "min!/6 happy path and ConditionalCheckFailed handling" do
    ts = ~N[2023-10-10 12:34:56]

    with_mock ExAws, request!: fn _op -> :ok end do
      assert {:ok, true} = BCR.min!(@table, @acc, @key, ts, 5.0)
    end

    with_mock ExAws, request!: fn _op ->
      raise ExAws.Error, message: "ConditionalCheckFailed: condition not met"
    end do
      assert {:ok, true} = BCR.min!(@table, @acc, @key, ts, 5.0)
    end
  end

  test "last_seen!/5 happy path and conditional handling" do
    ts = ~N[2023-10-10 12:34:56]

    with_mock ExAws, request!: fn _op -> :ok end do
      assert {:ok, true} = BCR.last_seen!(@table, @acc, @key, ts)
    end

    with_mock ExAws, request!: fn _op ->
      raise ExAws.Error, message: "ConditionalCheckFailed: condition not met"
    end do
      assert {:ok, true} = BCR.last_seen!(@table, @acc, @key, ts)
    end
  end
end
