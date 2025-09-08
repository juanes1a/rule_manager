defmodule MsEvaluateRules.Domain.UseCases.AccumulatorUseCaseTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Domain.UseCases.AccumulatorUseCase
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository

  describe "enrich_with_accs/3" do
    test "injects fields from accumulators with Decimal converted to float" do
      field_defs = %{
        "acc_score" => %{"acc_ref" => %{"name" => "login_events", "window" => "7d", "key" => "user_id"}}
      }

      typed_input = %{"user_id" => 10}
      raw_input = %{"user_id" => 10}

      with_mock AccumulatorsQueryRepository, [read: fn "login_events", %{"user_id" => 10}, %{window: "7d"} -> Decimal.new(5) end] do
        enriched = AccumulatorUseCase.enrich_with_accs(typed_input, field_defs, raw_input)
        assert enriched["acc_score"] == 5.0
      end
    end

    test "sets 0.0 on read failure" do
      field_defs = %{
        "acc_total" => %{"acc_ref" => %{"name" => "purchases", "window" => "1d", "key" => ["user_id", "country"]}}
      }

      typed_input = %{"user_id" => 1, "country" => "CO"}
      raw_input = typed_input

      with_mock AccumulatorsQueryRepository, [read: fn _, _, _ -> raise "boom" end] do
        enriched = AccumulatorUseCase.enrich_with_accs(typed_input, field_defs, raw_input)
        assert enriched["acc_total"] == 0.0
      end
    end
  end
end
