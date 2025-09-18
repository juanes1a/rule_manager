defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.RuleSetDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.RuleSetData

  test "valid changeset with defaults" do
    attrs = %{signature_id: Ecto.UUID.generate(), version: 1, status: :published}
    cs = RuleSetData.changeset(%RuleSetData{}, attrs)
    assert cs.valid?
  end

  test "invalid without required fields" do
    cs = RuleSetData.changeset(%RuleSetData{}, %{})
    refute cs.valid?
    assert Keyword.has_key?(cs.errors, :signature_id)
    assert Keyword.has_key?(cs.errors, :version)
    # status has default :draft, so it is present even if not provided
    refute Keyword.has_key?(cs.errors, :status)
  end

  test "invalid status value" do
    cs = RuleSetData.changeset(%RuleSetData{}, %{signature_id: Ecto.UUID.generate(), version: 1, status: :bad})
    refute cs.valid?
  end
end
