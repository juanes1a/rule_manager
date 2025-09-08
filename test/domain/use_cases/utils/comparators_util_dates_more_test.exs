defmodule MsEvaluateRules.Domain.UseCases.ComparatorsUtilDatesMoreTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.ComparatorsUtil, as: CU

  test "date covers !=, >=, <" do
    l = ~D[2024-01-10]
    assert CU.compare(l, "!=", "2024-01-09", "date") == true
    assert CU.compare(l, ">=", "2024-01-10", "date") == true
    assert CU.compare(l, "<", "2024-01-11", "date") == true
  end

  test "datetime covers !=, >=, <" do
    l = ~N[2024-01-10 12:00:00]
    assert CU.compare(l, "!=", "2024-01-10 11:00:00", "datetime") == true
    assert CU.compare(l, ">=", "2024-01-10 12:00:00", "datetime") == true
    assert CU.compare(l, "<", "2024-01-10 12:01:00", "datetime") == true
  end
end

