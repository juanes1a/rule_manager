defmodule MsEvaluateRules.Domain.UseCases.TypicalCoercionUtil do

  alias Decimal, as: D

  def coerce_input(input, field_defs) do
    Enum.reduce(field_defs, %{}, fn {k, %{"type" => t} = cfg}, acc ->
      v = Map.get(input, k)

      case coerce(v, t, cfg) do
        {:ok, cv} -> Map.put(acc, k, cv)
        :missing -> Map.put(acc, k, :__missing__)
        {:error, _} -> Map.put(acc, k, :__missing__)
      end
    end)
  end

  defp coerce(nil, _t, _), do: :missing
  defp coerce(v, "number", _), do: try_parse_number(v)
  defp coerce(v, "decimal", _), do: to_dec(v)
  defp coerce(v, "boolean", _), do: {:ok, v in [true, "true", 1, "1", "TRUE", "true"]}
  defp coerce(v, "string", _), do: {:ok, to_string(v)}
  defp coerce(v, "date", _), do: parse_date(v)
  defp coerce(v, "datetime", _), do: parse_ndt(v)
  defp coerce(v, "uuid", _), do: to_uuid(v)
  defp coerce(_v, _t, _), do: {:error, :unsupported}

  defp try_parse_number(v) when is_number(v), do: {:ok, v}

  defp try_parse_number(v) when is_binary(v) do
    case(Float.parse(v)) do
      {n, ""} -> {:ok, n}
      _ -> {:error, :nan}
    end
  end

  defp try_parse_number(_), do: {:error, :nan}

  def to_dec(%D{} = d), do: {:ok, d}
  def to_dec(v) when is_integer(v) or is_float(v), do: {:ok, D.new(v)}

  def to_dec(v) when is_binary(v) do
    case(D.new(v)) do
      %D{} = d -> {:ok, d}
      _ -> {:error, :bad_decimal}
    end
  rescue
    _ -> {:error, :bad_decimal}
  end

  def to_dec(_), do: {:error, :bad_decimal}

  def to_number(%D{} = d), do: d |> D.to_float()
  def to_number(v) when is_number(v), do: v

  def to_number(v) when is_binary(v) do
    case(Float.parse(v)) do
      {n, _} -> n
      _ -> 0
    end
  end

  def to_number(_), do: 0

  defp parse_date(%Date{} = d), do: {:ok, d}

  defp parse_date(v) when is_binary(v) do
    case(Date.from_iso8601(v)) do
      {:ok, d} -> {:ok, d}
      _ -> {:error, :bad_date}
    end
  end

  defp parse_date(_), do: {:error, :bad_date}

  defp parse_ndt(%NaiveDateTime{} = dt), do: {:ok, dt}

  defp parse_ndt(v) when is_binary(v) do
    case NaiveDateTime.from_iso8601(v) do
      {:ok, dt} ->
        {:ok, dt}

      _ ->
        case DateTime.from_iso8601(v) do
          {:ok, dt, _offset} -> {:ok, DateTime.to_naive(dt)}
          _ -> {:error, :bad_datetime}
        end
    end
  end

  defp parse_ndt(_), do: {:error, :bad_datetime}

  def to_ndt(%NaiveDateTime{} = dt), do: dt

  def to_ndt(v) when is_binary(v) do
    case(parse_ndt(v)) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  def to_ndt(_), do: nil

  def to_date(%Date{} = d), do: d

  def to_date(v) when is_binary(v) do
    case(Date.from_iso8601(v)) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  def to_date(_), do: nil

  def to_uuid(v) when is_binary(v) do
    case(Ecto.UUID.cast(v)) do
      {:ok, _} -> {:ok, v}
      _ -> {:error, :bad_uuid}
    end
  end

  def to_uuid(_), do: {:error, :bad_uuid}

  def to_int(v) when is_integer(v), do: v

  def to_int(v) when is_binary(v) do
    case(Integer.parse(v)) do
      {n, _} -> n
      _ -> 0
    end
  end

  def to_int(_), do: 0
end
