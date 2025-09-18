defmodule MsEvaluateRules.Domain.UseCases.AccumulatorUseCaseExtendedTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Domain.UseCases.AccumulatorUseCase
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    AccumulatorsQueryRepository,
    Accumulator
  }
  alias MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository

  setup do
    :ok
  end

  test "compute ratio uses default when denominator is 0" do
    field_defs = %{
      "ratio1" => %{
        "compute" => "ratio",
        "num" => %{"acc_ref" => %{"name" => "n7", "window" => "7d", "key" => "user_id"}},
        "den" => %{"acc_ref" => %{"name" => "d7", "window" => "7d", "key" => "user_id"}},
        "default" => 0.0
      }
    }

    typed = %{"user_id" => 1}
    raw = %{"user_id" => 1}

    defn_n = %Accumulator{id: Ecto.UUID.generate(), name: "n7", status: :active, bucket_gran: :day, dimensions: ["user_id"]}
    defn_d = %Accumulator{id: Ecto.UUID.generate(), name: "d7", status: :active, bucket_gran: :day, dimensions: ["user_id"]}

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        get_accumulator_definition: fn
          "n7" -> {:ok, defn_n}
          "d7" -> {:ok, defn_d}
        end
      ]},
      {BucketQueryRepository, [], [
        sum_window: fn
          ^defn_n, _key_hash, _ref -> 10.0
          ^defn_d, _key_hash, _ref -> 0.0
        end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["ratio1"] == 0.0
    end
  end

  test "compute ratio divides when denominator > 0" do
    field_defs = %{
      "ratio2" => %{
        "compute" => "ratio",
        "num" => %{"acc_ref" => %{"name" => "n7", "window" => "7d", "key" => "user_id"}},
        "den" => %{"acc_ref" => %{"name" => "d7", "window" => "7d", "key" => "user_id"}},
        "default" => 0.0
      }
    }

    typed = %{"user_id" => 1}
    raw = %{"user_id" => 1}

    defn_n = %Accumulator{id: Ecto.UUID.generate(), name: "n7", status: :active, bucket_gran: :day, dimensions: ["user_id"]}
    defn_d = %Accumulator{id: Ecto.UUID.generate(), name: "d7", status: :active, bucket_gran: :day, dimensions: ["user_id"]}

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        get_accumulator_definition: fn
          "n7" -> {:ok, defn_n}
          "d7" -> {:ok, defn_d}
        end
      ]},
      {BucketQueryRepository, [], [
        sum_window: fn
          ^defn_n, _key_hash, _ref -> 10.0
          ^defn_d, _key_hash, _ref -> 2.0
        end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["ratio2"] == 5.0
    end
  end

  test "compute rate delegates to query repo and converts Decimal to float" do
    field_defs = %{
      "rate1" => %{
        "compute" => "rate",
        "acc_ref" => %{"name" => "sum1h", "window" => "1h", "key" => "user_id"},
        "per" => "minute"
      }
    }

    typed = %{"user_id" => 1}
    raw = %{"user_id" => 1}

    defn = %Accumulator{id: Ecto.UUID.generate(), name: "sum1h", status: :active, bucket_gran: :day, dimensions: ["user_id"]}

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        get_accumulator_definition: fn "sum1h" -> {:ok, defn} end
      ]},
      {BucketQueryRepository, [], [
        sum_window: fn ^defn, _key_hash, _ref -> 360.0 end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      # 360 over 1h => per minute 6.0
      assert out["rate1"] == 6.0
    end
  end

  test "compute extreme max/min delegations" do
    field_defs = %{
      "mx" => %{"compute" => "extreme", "op" => "max", "acc_ref" => %{"name" => "m", "window" => "1d", "key" => "user_id"}},
      "mn" => %{"compute" => "extreme", "op" => "min", "acc_ref" => %{"name" => "m", "window" => "1d", "key" => "user_id"}}
    }

    typed = %{"user_id" => 1}
    raw = %{"user_id" => 1}

    defn = %Accumulator{id: Ecto.UUID.generate(), name: "m", status: :active, bucket_gran: :day, dimensions: ["user_id"]}

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        get_accumulator_definition: fn "m" -> {:ok, defn} end
      ]},
      {BucketQueryRepository, [], [
        extreme_window: fn ^defn, _key_hash, _ref, which -> if(which == :max, do: 9.0, else: 1.0) end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["mx"] == 9.0
      assert out["mn"] == 1.0
    end
  end

  test "time_since_last uses default on :infinite and passes integer value" do
    field_defs = %{
      "since" => %{
        "compute" => "time_since_last",
        "acc_ref" => %{"name" => "ev", "key" => ["user_id", "country"]},
        "default" => 999
      }
    }

    typed = %{"user_id" => 1, "country" => "CO"}
    raw = typed

    defn = %Accumulator{id: Ecto.UUID.generate(), name: "ev", status: :active, bucket_gran: :day, dimensions: ["user_id", "country"]}

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        get_accumulator_definition: fn "ev" -> {:ok, defn} end
      ]},
      {BucketQueryRepository, [], [
        time_since_last: fn _acc_id, _key_hash -> :infinite end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["since"] == 999
    end

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        get_accumulator_definition: fn "ev" -> {:ok, defn} end
      ]},
      {BucketQueryRepository, [], [
        time_since_last: fn _acc_id, _key_hash -> 42 end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["since"] == 42
    end
  end
end
