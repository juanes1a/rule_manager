defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.SignatureDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.SignatureData

  test "valid changeset" do
    attrs = %{
      app_id: Ecto.UUID.generate(),
      name: "sig-1",
      output_mode: :score,
      aggregation: :sum,
      mapping: %{"thresholds" => [], "default" => %{"result" => false}},
      field_defs: %{}
    }

    cs = SignatureData.changeset(%SignatureData{}, attrs)
    assert cs.valid?
  end

  test "missing required fields invalid" do
    cs = SignatureData.changeset(%SignatureData{}, %{})
    refute cs.valid?
    assert Keyword.has_key?(cs.errors, :app_id)
    assert Keyword.has_key?(cs.errors, :name)
    assert Keyword.has_key?(cs.errors, :output_mode)
    assert Keyword.has_key?(cs.errors, :aggregation)
    assert Keyword.has_key?(cs.errors, :mapping)
    assert Keyword.has_key?(cs.errors, :field_defs)
  end
end

