defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.AuditLogDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.AuditLogData

  test "valid changeset" do
    attrs = %{
      actor: "user-1",
      entity_type: "rule",
      entity_id: Ecto.UUID.generate(),
      action: "create",
      before: %{},
      after: %{}
    }

    cs = AuditLogData.changeset(%AuditLogData{}, attrs)
    assert cs.valid?
  end

  test "invalid without mandatory fields" do
    cs = AuditLogData.changeset(%AuditLogData{}, %{})
    refute cs.valid?
    assert Keyword.has_key?(cs.errors, :actor)
    assert Keyword.has_key?(cs.errors, :entity_type)
    assert Keyword.has_key?(cs.errors, :entity_id)
    assert Keyword.has_key?(cs.errors, :action)
  end
end

