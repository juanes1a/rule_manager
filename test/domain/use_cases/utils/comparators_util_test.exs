defmodule MsEvaluateRules.Domain.UseCases.ComparatorsUtilTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.ComparatorsUtil, as: CU

  describe "missing/exists + var resolution" do
    test "missing is true only when left is :__missing__" do
      assert CU.compare(:__missing__, "missing", 1, "string") == true
      assert CU.compare("x", "missing", 1, "string") == false
    end

    test "exists is true only when left exists" do
      assert CU.compare(:__missing__, "exists", 1, "string") == false
      assert CU.compare("x", "exists", 1, "string") == true
    end

    test "var resolution yields :__missing__ on right and returns false" do
      assert CU.compare(10, "=", %{"var" => "x"}, "number") == false
      assert CU.compare("a", "=", %{"var" => "y"}, "string") == false
    end

    test "short-circuit when left or right is :__missing__" do
      assert CU.compare(:__missing__, "=", 1, "number") == false
      assert CU.compare(1, "=", :__missing__, "number") == false
    end
  end

  describe "number comparisons" do
    test "basic ordering and equality" do
      assert CU.compare(2, "=", 2, "number") == true
      assert CU.compare(2, "!=", 3, "number") == true
      assert CU.compare(3, ">", 2, "number") == true
      assert CU.compare(3, ">=", 3, "number") == true
      assert CU.compare(2, "<", 3, "number") == true
      assert CU.compare(3, "<=", 3, "number") == true
    end

    test "unsupported ops for number return false" do
      assert CU.compare(1, "in",  [1], "number") == false
      assert CU.compare(1, "not_in", [1], "number") == false
    end

    test "non-number falls back to false" do
      assert CU.compare("a", "=", 1, "number") == false
    end
  end

  describe "decimal comparisons" do
    test "eq/gt/lt branches and op mapping (no floats)" do
      # equal
      assert CU.compare("1.50", "=", "1.5", "decimal") == true
      assert CU.compare(5, ">=", 5, "decimal") == true
      assert CU.compare(5, "<=", 5, "decimal") == true
      assert CU.compare(5, "in", 5, "decimal") == true
      assert CU.compare(5, ">", 5, "decimal") == false

      # greater than
      assert CU.compare(6, ">", 5, "decimal") == true
      assert CU.compare(6, ">=", 5, "decimal") == true
      assert CU.compare(6, "not_in", 5, "decimal") == true
      assert CU.compare(6, "<", 5, "decimal") == false

      # less than
      assert CU.compare(4, "<", 5, "decimal") == true
      assert CU.compare(4, "<=", 5, "decimal") == true
      assert CU.compare(4, "not_in", 5, "decimal") == true
      assert CU.compare(4, ">", 5, "decimal") == false
    end

    test "bad decimal conversion returns false" do
      assert CU.compare("abc", "=", 1, "decimal") == false
      assert CU.compare(1, "=", "abc", "decimal") == false
    end
  end

  describe "string comparisons" do
    test "equality and contains/starts_with/ends_with" do
      assert CU.compare("hello", "=", "hello", "string") == true
      assert CU.compare("hello", "!=", "world", "string") == true
      assert CU.compare("hello", "contains", "ell", "string") == true
      assert CU.compare("hello", "starts_with", "he", "string") == true
      assert CU.compare("hello", "ends_with", "lo", "string") == true
    end

    test "regex ok and bad pattern" do
      assert CU.compare("abc123", "regex", "\\d+", "string") == true
      assert CU.compare("abc", "regex", "[", "string") == false
    end

    test "length_* operators and length_between" do
      assert CU.compare("abcd", "length_eq", 4, "string") == true
      assert CU.compare("abcd", "length_gt", 3, "string") == true
      assert CU.compare("abcd", "length_lt", 5, "string") == true
      assert CU.compare("abcd", "length_between", [3, 5], "string") == true
      assert CU.compare("abcd", "length_between", :bad, "string") == false
    end

    test "in and not_in on list of values" do
      assert CU.compare("x", "in", ["a", "x", 1], "string") == true
      assert CU.compare("x", "not_in", ["a", 1], "string") == true
      assert CU.compare("x", "not_in", ["x"], "string") == false
    end

    test "unknown op returns false" do
      assert CU.compare("x", "unknown", "y", "string") == false
    end
  end

  describe "boolean comparisons" do
    test "only = and != supported" do
      assert CU.compare(true, "=", true, "boolean") == true
      assert CU.compare(true, "!=", false, "boolean") == true
      assert CU.compare(true, ">", false, "boolean") == false
    end
  end

  describe "date comparisons" do
    test "basic ops and invalid right" do
      l = ~D[2024-01-10]
      assert CU.compare(l, "=", "2024-01-10", "date") == true
      assert CU.compare(l, ">", "2024-01-01", "date") == true
      assert CU.compare(l, "<=", "2024-01-09", "date") == false
      assert CU.compare(l, "=", "bad-date", "date") == false
    end

    test "between is inclusive on bounds" do
      l = ~D[2024-01-10]
      assert CU.compare(l, "between", ["2024-01-10", "2024-01-11"], "date") == true
      assert CU.compare(l, "between", ["2024-01-09", "2024-01-10"], "date") == true
      assert CU.compare(l, "between", ["2024-01-11", "2024-01-12"], "date") == false
      assert CU.compare(l, "between", ["bad", "2024-01-12"], "date") == false
    end
  end

  describe "datetime comparisons" do
    test "basic ops and invalid right" do
      l = ~N[2024-01-10 12:00:00]
      assert CU.compare(l, "=", "2024-01-10 12:00:00", "datetime") == true
      assert CU.compare(l, ">", "2024-01-10 11:00:00", "datetime") == true
      assert CU.compare(l, "<=", "2024-01-10 13:00:00", "datetime") == true
      assert CU.compare(l, "=", "bad-dt", "datetime") == false
    end

    test "between is inclusive on bounds" do
      l = ~N[2024-01-10 12:00:00]
      assert CU.compare(l, "between", ["2024-01-10 12:00:00", "2024-01-10 13:00:00"], "datetime") == true
      assert CU.compare(l, "between", ["2024-01-10 11:00:00", "2024-01-10 12:00:00"], "datetime") == true
      assert CU.compare(l, "between", ["2024-01-10 13:00:00", "2024-01-10 14:00:00"], "datetime") == false
      assert CU.compare(l, "between", ["bad", "2024-01-10 14:00:00"], "datetime") == false
    end
  end

  describe "uuid comparisons" do
    test "basic ops (list membership not supported by current impl)" do
      u1 = Ecto.UUID.generate()
      u2 = Ecto.UUID.generate()
      assert CU.compare(u1, "=", u1, "uuid") == true
      assert CU.compare(u1, "!=", u2, "uuid") == true
      # current implementation attempts to cast list as string; expect false
      assert CU.compare(u1, "in", [u2, u1], "uuid") == false
      assert CU.compare(u1, "not_in", [u2], "uuid") == true
    end

    test "equality is case-sensitive (current behavior)" do
      u = Ecto.UUID.generate()
      up = String.upcase(u)
      # Both cast ok but compare uses raw string equality
      assert CU.compare(u, "=", up, "uuid") == (u == up)
    end

    test "invalid casts return false" do
      bad = "not-a-uuid"
      good = Ecto.UUID.generate()
      assert CU.compare(bad, "=", good, "uuid") == false
      assert CU.compare(good, "=", bad, "uuid") == false
    end
  end

  test "unknown type falls back to false" do
    assert CU.compare(1, "=", 1, "unknown") == false
  end

  describe "strings length_* with numeric strings" do
    test "length operators accept numeric strings for r" do
      s = "abcd"
      assert CU.compare(s, "length_eq", "4", "string") == true
      assert CU.compare(s, "length_gt", "3", "string") == true
      assert CU.compare(s, "length_lt", "5", "string") == true
      assert CU.compare(s, "length_between", ["3", "5"], "string") == true
    end
  end

  describe "mixed numeric types" do
    test "integer vs float works for number type" do
      assert CU.compare(2, "=", 2.0, "number") == true
      assert CU.compare(2, "<", 2.5, "number") == true
      assert CU.compare(2.5, ">", 2, "number") == true
    end

    test "boolean with non-boolean right returns false" do
      assert CU.compare(true, "=", "true", "boolean") == false
    end
  end
end
