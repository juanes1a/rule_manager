defmodule MsEvaluateRules.Domain.UseCases.ComparatorsUtilAdditionalTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.ComparatorsUtil, as: CU

  test "boolean equality false and not-equal false" do
    assert CU.compare(true, "=", false, "boolean") == false
    assert CU.compare(true, "!=", true, "boolean") == false
  end

  test "string contains/starts/ends negative cases" do
    s = "hello"
    assert CU.compare(s, "contains", "xyz", "string") == false
    assert CU.compare(s, "starts_with", "zz", "string") == false
    assert CU.compare(s, "ends_with", "zz", "string") == false
  end

  test "decimal in/not_in negative cases" do
    # in false when different
    assert CU.compare(5, "in", 4, "decimal") == false
    # not_in false when equal
    assert CU.compare(5, "not_in", 5, "decimal") == false
  end

  test "uuid list membership not supported (both ops false)" do
    u1 = Ecto.UUID.generate()
    u2 = Ecto.UUID.generate()
    assert CU.compare(u1, "in", [u2, u1], "uuid") == false
    assert CU.compare(u1, "not_in", [u2, u1], "uuid") == false
  end

  test "date and datetime unknown operators return false" do
    assert CU.compare(~D[2024-01-01], "unknown", "2024-01-01", "date") == false
    assert CU.compare(~N[2024-01-01 00:00:00], "unknown", "2024-01-01 00:00:00", "datetime") == false
  end
end
