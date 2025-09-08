defmodule MsEvaluateRules.Domain.UseCases.TypicalCoercionUtilTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.TypicalCoercionUtil, as: TU
  alias Decimal, as: D

  describe "coerce_input/2" do
    test "coerces all supported types and marks missing/error as :__missing__" do
      field_defs = %{
        "n" => %{"type" => "number"},
        "dec" => %{"type" => "decimal"},
        "b" => %{"type" => "boolean"},
        "s" => %{"type" => "string"},
        "d" => %{"type" => "date"},
        "dt" => %{"type" => "datetime"},
        "u" => %{"type" => "uuid"},
        "bad" => %{"type" => "unknown"}
      }

      good_uuid = Ecto.UUID.generate()

      input = %{
        "n" => "12.5",
        "dec" => "3.14",
        "b" => "true",
        "s" => 123,
        "d" => "2024-01-10",
        "dt" => "2024-01-10 12:00:00",
        "u" => good_uuid
        # "bad" intentionally omitted to cover missing
      }

      out = TU.coerce_input(input, field_defs)

      assert out["n"] == 12.5
      assert match?(%D{} , elem(TU.to_dec(out["dec"]), 1)) == true # ensure dec is already Decimal or convertible
      # We can assert as Decimal using pattern match on parse
      assert {:ok, %D{}} = TU.to_dec(out["dec"]) # coercion returns Decimal-compatible
      assert out["b"] == true
      assert out["s"] == "123"
      assert match?(%Date{}, out["d"])
      assert match?(%NaiveDateTime{}, out["dt"])
      assert out["u"] == good_uuid
      assert out["bad"] == :__missing__
    end

    test "invalid values become :__missing__" do
      field_defs = %{"dec" => %{"type" => "decimal"}, "u" => %{"type" => "uuid"}}
      input = %{"dec" => "bad", "u" => "not-uuid"}
      out = TU.coerce_input(input, field_defs)
      assert out["dec"] == :__missing__
      assert out["u"] == :__missing__
    end
  end

  describe "to_dec/1 and to_number/1" do
    test "decimal conversions" do
      assert {:ok, %D{}} = TU.to_dec(1)
      assert {:ok, %D{}} = TU.to_dec(1.2)
      assert {:ok, %D{}} = TU.to_dec("1.20")
      assert {:error, :bad_decimal} = TU.to_dec("abc")
    end

    test "to_number from decimal/number/string/other" do
      d = elem(TU.to_dec("2.50"), 1)
      assert is_float(TU.to_number(d))
      assert TU.to_number(3) == 3
      assert TU.to_number(3.5) == 3.5
      assert TU.to_number("4.2") == 4.2
      assert TU.to_number(:nope) == 0
    end
  end

  describe "dates and datetimes" do
    test "to_date" do
      assert TU.to_date("2024-01-11") == ~D[2024-01-11]
      assert TU.to_date("bad") == nil
      assert TU.to_date(:x) == nil
    end

    test "to_ndt" do
      assert TU.to_ndt("2024-01-10 13:00:00") == ~N[2024-01-10 13:00:00]
      # ISO8601 with Z timezone
      assert match?(%NaiveDateTime{}, TU.to_ndt("2024-01-10T12:00:00Z"))
      assert TU.to_ndt("bad") == nil
      assert TU.to_ndt(:x) == nil
    end
  end

  describe "uuid and int helpers" do
    test "uuid casting and to_int" do
      u = Ecto.UUID.generate()
      assert {:ok, ^u} = TU.to_uuid(u)
      assert {:error, :bad_uuid} = TU.to_uuid("bad")
      assert TU.to_int(5) == 5
      assert TU.to_int("6") == 6
      assert TU.to_int(:bad) == 0
    end
  end
end
