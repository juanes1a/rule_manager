defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.RuleDataTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.RuleData

  test "valid changeset" do
    attrs = %{
      ruleset_id: Ecto.UUID.generate(),
      name: "r1",
      priority: 0,
      enabled: true,
      condition: %{"field" => "x"},
      effects: []
    }

    cs = RuleData.changeset(%RuleData{}, attrs)
    assert cs.valid?
  end

  test "invalid when priority negative" do
    attrs = %{
      ruleset_id: Ecto.UUID.generate(),
      name: "r1",
      priority: -1,
      condition: %{"field" => "x"},
      effects: []
    }

    cs = RuleData.changeset(%RuleData{}, attrs)
    refute cs.valid?
    assert Keyword.has_key?(cs.errors, :priority)
  end
end

