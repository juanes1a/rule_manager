defmodule MsEvaluateRules.Domain.UseCases.ComparatorsUtilEdgecasesTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.ComparatorsUtil, as: CU

  test "string in/not_in with non-list right returns false" do
    assert CU.compare("x", "in", "x", "string") == false
    assert CU.compare("x", "not_in", "y", "string") == false
  end

  test "decimal unknown operator returns false" do
    assert CU.compare(5, "unknown", 5, "decimal") == false
  end

  test "datetime between with non-list returns false" do
    l = ~N[2024-01-10 12:00:00]
    assert CU.compare(l, "between", "2024-01-10 13:00:00", "datetime") == false
  end

  test "date between with non-list returns false" do
    l = ~D[2024-01-10]
    assert CU.compare(l, "between", "2024-01-11", "date") == false
  end

  test "boolean with invalid types returns false" do
    assert CU.compare("true", "=", true, "boolean") == false
  end
end

