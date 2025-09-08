defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.BucketDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.Bucket

  describe "Bucket.changeset/2" do
    test "requires mandatory fields" do
      cs = Bucket.changeset(%Bucket{}, %{})
      refute cs.valid?
      assert %{accumulator_id: ["can't be blank"], bucket_start: ["can't be blank"], key_json: ["can't be blank"], key_hash: ["can't be blank"]} = errors_on(cs)
    end

    test "accepts valid payload" do
      params = %{
        accumulator_id: Ecto.UUID.generate(),
        bucket_start: DateTime.utc_now(),
        key_json: %{user_id: 1},
        key_hash: :crypto.hash(:sha256, "{}"),
        value_num: Decimal.new(5)
      }

      cs = Bucket.changeset(%Bucket{}, params)
      assert cs.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

