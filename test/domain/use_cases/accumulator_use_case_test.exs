defmodule MsEvaluateRules.Domain.UseCases.AccumulatorUseCaseTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Domain.UseCases.AccumulatorUseCase
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    AccumulatorsQueryRepository,
    Accumulator
  }
  alias MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository

  describe "enrich_with_accs/3" do
    test "injects fields from accumulators using Dynamo bucket reader" do
      field_defs = %{
        "acc_score" => %{"acc_ref" => %{"name" => "login_events", "window" => "7d", "key" => "user_id"}}
      }

      typed_input = %{"user_id" => 10}
      raw_input = %{"user_id" => 10}

      defn = %Accumulator{id: Ecto.UUID.generate(), name: "login_events", status: :active, bucket_gran: :day, dimensions: ["user_id"]}

      with_mocks [
        {AccumulatorsQueryRepository, [], [
          get_accumulator_definition: fn "login_events" -> {:ok, defn} end
        ]},
        {BucketQueryRepository, [], [
          sum_window: fn ^defn, _key_hash, _ref -> 5.0 end
        ]}
      ] do
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

      defn = %Accumulator{id: Ecto.UUID.generate(), name: "purchases", status: :active, bucket_gran: :day, dimensions: ["user_id", "country"]}

      with_mocks [
        {AccumulatorsQueryRepository, [], [
          get_accumulator_definition: fn "purchases" -> {:ok, defn} end
        ]},
        {BucketQueryRepository, [], [
          sum_window: fn ^defn, _key_hash, _ref -> :error end
        ]}
      ] do
        enriched = AccumulatorUseCase.enrich_with_accs(typed_input, field_defs, raw_input)
        assert enriched["acc_total"] == 0.0
      end

      # when accumulator not found
      with_mock AccumulatorsQueryRepository, [
        get_accumulator_definition: fn "purchases" -> {:error, :not_found} end
      ] do
        enriched = AccumulatorUseCase.enrich_with_accs(typed_input, field_defs, raw_input)
        assert enriched["acc_total"] == 0.0
      end
    end

    test "normalize_key/2 retains dims order and allows nils" do
      assert {:ok, %{"a" => 1, "b" => nil}} = AccumulatorUseCase.normalize_key(%{"a" => 1}, ["a", "b"])
    end

    test "ignores unknown spec entries" do
      typed = %{"x" => 1}
      spec = %{"unknown" => %{}}
      assert AccumulatorUseCase.enrich_with_accs(typed, spec, %{}) == typed
    end
  end
end
