defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.AccumulatorDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.Accumulator

  describe "Accumulator.changeset/2" do
    test "validates required fields" do
      cs = Accumulator.changeset(%Accumulator{}, %{})
      refute cs.valid?
      assert %{name: ["can't be blank"], kind: ["can't be blank"], bucket_gran: ["can't be blank"]} = errors_on(cs)
    end

    test "accepts valid enum values" do
      params = %{
        name: "acc_events",
        description: "Event counter",
        kind: :count,
        dimensions: ["user_id", "country"],
        value_field: nil,
        bucket_gran: :day,
        retention_days: 30,
        status: :active
      }

      cs = Accumulator.changeset(%Accumulator{}, params)
      assert cs.valid?
    end
  end

  # Helpers
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

