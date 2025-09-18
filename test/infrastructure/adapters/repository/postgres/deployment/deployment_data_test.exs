defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.DeploymentDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.DeploymentData

  test "valid changeset" do
    attrs = %{
      signature_id: Ecto.UUID.generate(),
      ruleset_id: Ecto.UUID.generate(),
      version: 1,
      activated_by: "user",
      activated_at: ~U[2024-01-10 12:00:00Z],
      notes: "initial"
    }

    cs = DeploymentData.changeset(%DeploymentData{}, attrs)
    assert cs.valid?
  end

  test "invalid without mandatory fields" do
    cs = DeploymentData.changeset(%DeploymentData{}, %{})
    refute cs.valid?
    assert Keyword.has_key?(cs.errors, :signature_id)
    assert Keyword.has_key?(cs.errors, :ruleset_id)
    assert Keyword.has_key?(cs.errors, :version)
    assert Keyword.has_key?(cs.errors, :activated_by)
  end
end

