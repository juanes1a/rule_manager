defmodule MsEvaluateRules.Domain.UseCases.ComparatorsUtil do

  import MsEvaluateRules.Domain.UseCases.TypicalCoercionUtil,
  only: [to_dec: 1, to_int: 1, to_date: 1, to_ndt: 1]

  alias Decimal, as: D


    # === Comparadores (null/missing-safe) ===
  def compare(:__missing__, "missing", _r, _), do: true
  def compare(_v, "missing", _r, _), do: false

  def compare(:__missing__, "exists", _r, _), do: false
  def compare(v, "exists", _r, _), do: v != :__missing__

  # Re-resolver {"var":...} contra input si hace falta
  def compare(left, op, %{"var" => name}, t) do
    compare(left, op, Map.get(%{}, name, :__missing__), t)
  end

  # Cortes por missing
  def compare(:__missing__, _op, _r, _), do: false
  def compare(_l, _op, :__missing__, _), do: false

  # number (float)
  def compare(l, op, r, "number") when is_number(l) and is_number(r), do: do_ord(op, l, r)

  # decimal (exacto)
  def compare(l, op, r, "decimal") do
    with {:ok, dl} <- to_dec(l), {:ok, dr} <- to_dec(r) do
      case D.compare(dl, dr) do
        :eq -> op in ["=", ">=", "<=", "in"]
        :gt -> op in [">", ">=", "not_in"]
        :lt -> op in ["<", "<=", "not_in"]
      end
    else
      _ -> false
    end
  end

  # string
  def compare(l, op, r, "string") when is_binary(l) do
    case op do
      "=" ->
        l == to_string(r)

      "!=" ->
        l != to_string(r)

      "contains" ->
        String.contains?(l, to_string(r))

      "starts_with" ->
        String.starts_with?(l, to_string(r))

      "ends_with" ->
        String.ends_with?(l, to_string(r))

      "regex" ->
        case Regex.compile(to_string(r)) do
          {:ok, re} -> Regex.match?(re, l)
          _ -> false
        end

      "length_eq" ->
        String.length(l) == to_int(r)

      "length_gt" ->
        String.length(l) > to_int(r)

      "length_lt" ->
        String.length(l) < to_int(r)

      "length_between" ->
        case r do
          [a, b] -> String.length(l) >= to_int(a) and String.length(l) <= to_int(b)
          _ -> false
        end

      "in" ->
        is_list(r) and Enum.any?(r, &(to_string(&1) == l))

      "not_in" ->
        is_list(r) and Enum.all?(r, &(to_string(&1) != l))

      _ ->
        false
    end
  end

  # boolean
  def compare(l, op, r, "boolean") when is_boolean(l) and is_boolean(r) do
    case op do
      "=" -> l == r
      "!=" -> l != r
      _ -> false
    end
  end

  # date
  def compare(%Date{} = l, "between", r, "date") when is_list(r), do: do_date("between", l, r)
  def compare(%Date{} = l, op, r, "date") do
    r1 = to_date(r)
    if is_nil(r1), do: false, else: do_date(op, l, r1)
  end

  # datetime (NaiveDateTime)
  def compare(%NaiveDateTime{} = l, "between", r, "datetime") when is_list(r),
    do: do_ndt("between", l, r)

  def compare(%NaiveDateTime{} = l, op, r, "datetime") do
    r1 = to_ndt(r)
    if is_nil(r1), do: false, else: do_ndt(op, l, r1)
  end

  # uuid
  def compare(<<_::binary>> = l, op, r, "uuid") do
    case {Ecto.UUID.cast(l), Ecto.UUID.cast(to_string(r))} do
      {{:ok, _}, {:ok, _}} ->
        case op do
          "=" -> l == to_string(r)
          "!=" -> l != to_string(r)
          "in" -> is_list(r) and Enum.member?(Enum.map(r, &to_string/1), l)
          "not_in" -> is_list(r) and not Enum.member?(Enum.map(r, &to_string/1), l)
          _ -> false
        end

      _ ->
        false
    end
  end

  def compare(_l, _op, _r, _), do: false

  # === Helpers de comparación ===
  defp do_ord(op, l, r) do
    case op do
      "=" -> l == r
      "!=" -> l != r
      ">" -> l > r
      ">=" -> l >= r
      "<" -> l < r
      "<=" -> l <= r
      "in" -> false
      "not_in" -> false
      _ -> false
    end
  end

  defp do_date("between", %Date{} = l, [a, b]) do
    a1 = to_date(a)
    b1 = to_date(b)
    (a1 != nil) and (b1 != nil) and Date.compare(l, a1) in [:gt, :eq] and Date.compare(l, b1) in [:lt, :eq]
  end

  defp do_date(op, l, r) do
    case op do
      "=" -> l == r
      "!=" -> l != r
      ">" -> Date.compare(l, r) == :gt
      ">=" -> Date.compare(l, r) in [:gt, :eq]
      "<" -> Date.compare(l, r) == :lt
      "<=" -> Date.compare(l, r) in [:lt, :eq]
      _ -> false
    end
  end

  defp do_ndt("between", %NaiveDateTime{} = l, [a, b]) do
    a1 = to_ndt(a)
    b1 = to_ndt(b)

    (a1 != nil) and (b1 != nil) and NaiveDateTime.compare(l, a1) in [:gt, :eq] and
      NaiveDateTime.compare(l, b1) in [:lt, :eq]
  end

  defp do_ndt(op, l, r) do
    case op do
      "=" -> l == r
      "!=" -> l != r
      ">" -> NaiveDateTime.compare(l, r) == :gt
      ">=" -> NaiveDateTime.compare(l, r) in [:gt, :eq]
      "<" -> NaiveDateTime.compare(l, r) == :lt
      "<=" -> NaiveDateTime.compare(l, r) in [:lt, :eq]
      _ -> false
    end
  end
end
