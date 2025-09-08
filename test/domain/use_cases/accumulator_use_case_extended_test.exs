defmodule MsEvaluateRules.Domain.UseCases.AccumulatorUseCaseExtendedTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Domain.UseCases.AccumulatorUseCase
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository

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

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        read: fn
          "n7", %{"user_id" => 1}, %{window: "7d"} -> Decimal.new(10)
          "d7", %{"user_id" => 1}, %{window: "7d"} -> Decimal.new(0)
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

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        read: fn
          "n7", %{"user_id" => 1}, %{window: "7d"} -> Decimal.new(10)
          "d7", %{"user_id" => 1}, %{window: "7d"} -> Decimal.new(2)
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

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        read_rate: fn "sum1h", %{"user_id" => 1}, %{window: "1h", per: :minute} -> Decimal.new(6) end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
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

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        read_max: fn "m", %{"user_id" => 1}, %{window: "1d"} -> Decimal.new(9) end,
        read_min: fn "m", %{"user_id" => 1}, %{window: "1d"} -> Decimal.new(1) end
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

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        read_time_since_last: fn "ev", %{"user_id" => 1, "country" => "CO"} -> :infinite end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["since"] == 999
    end

    with_mocks [
      {AccumulatorsQueryRepository, [], [
        read_time_since_last: fn "ev", %{"user_id" => 1, "country" => "CO"} -> 42 end
      ]}
    ] do
      out = AccumulatorUseCase.enrich_with_accs(typed, field_defs, raw)
      assert out["since"] == 42
    end
  end
end
