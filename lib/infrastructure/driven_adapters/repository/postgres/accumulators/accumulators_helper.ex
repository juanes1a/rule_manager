defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelper do
  def normalize_ts(%NaiveDateTime{} = ts), do: {:ok, ts}

  def normalize_ts(%DateTime{} = dt), do: {:ok, DateTime.to_naive(dt)}

  def normalize_ts(%Date{} = d), do: {:ok, NaiveDateTime.new!(d, ~T[00:00:00])}

  def normalize_ts(ts) when is_binary(ts) do
    case NaiveDateTime.from_iso8601(ts) do
      {:ok, ndt} ->
        {:ok, ndt}

      _ ->
        case DateTime.from_iso8601(ts) do
          {:ok, dt, _} -> {:ok, DateTime.to_naive(dt)}
          _ -> {:error, :bad_ts}
        end
    end
  end

  def normalize_ts(ts) when is_integer(ts) do
    # epoch seconds → NaiveDateTime (UTC)
    {:ok, ts |> DateTime.from_unix!() |> DateTime.to_naive()}
  end

  def normalize_ts(_), do: {:error, :bad_ts}

  # Truncado por granularidad (acepta day/hour/minute)
  def truncate_to_gran(%NaiveDateTime{} = ts, "day"),
    do: %{ts | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

  def truncate_to_gran(%NaiveDateTime{} = ts, "hour"),
    do: %{ts | minute: 0, second: 0, microsecond: {0, 0}}

  def truncate_to_gran(%NaiveDateTime{} = ts, "minute"),
    do: %{ts | second: 0, microsecond: {0, 0}}

  def truncate_to_gran(%NaiveDateTime{} = ts, _), do: ts

  def shift_window(%DateTime{} = now, window) do
    case Regex.run(~r/^(\d+)([mhd])$/, window) do
      [_, n, unit] ->
        n = String.to_integer(n)

        secs =
          case unit do
            "m" -> 60
            "h" -> 3600
            "d" -> 86400
          end

        {:ok, DateTime.add(now, -n * secs, :second)}

      _ ->
        {:error, :bad_window}
    end
  end

  def normalize_key(map, dims) do
    {
      :ok,
      dims |> Enum.map(&{&1, Map.get(map, &1)}) |> Enum.into(%{})
    }
  end

  def normalize_per(p) when is_atom(p), do: p

  def normalize_per(p) when is_binary(p) do
    case String.downcase(p) do
      "second" -> :second
      "minute" -> :minute
      "hour" -> :hour
      "day" -> :day
      _ -> :second
    end
  end

  def normalize_per(_), do: :second

  def per_to_base(:second), do: 1
  def per_to_base(:minute), do: 60
  def per_to_base(:hour), do: 3600
  def per_to_base(:day), do: 86_400

  # --- robusto, acepta "7d" / "24h" / "90m" (con o sin espacios, mayúsculas) ---
  def shift_window(%DateTime{} = now, window) when is_binary(window) do
    case Regex.run(~r/^\s*(\d+)\s*([mhd])\s*$/i, window) do
      [_, n_str, unit] ->
        n = String.to_integer(n_str)

        secs =
          case String.downcase(unit) do
            "m" -> 60
            "h" -> 3_600
            "d" -> 86_400
          end

        {:ok, DateTime.add(now, -n * secs, :second)}

      _ ->
        {:error, :bad_window}
    end
  end

  # Si alguna vez te llega NaiveDateTime, lo convertimos a UTC para reutilizar la lógica
  def shift_window(%NaiveDateTime{} = now, window) when is_binary(window) do
    now
    |> DateTime.from_naive!("Etc/UTC")
    |> shift_window(window)
  end

  # Wrapper para usar en consultas Ecto con campos :utc_datetime (NaiveDateTime)
  def window_from_now(window) when is_binary(window) do
    case shift_window(DateTime.utc_now(), window) do
      # ✅ NaiveDateTime
      {:ok, dt} ->
        DateTime.to_naive(dt)

      {:error, _} ->
        # fallback 24h
        DateTime.utc_now() |> DateTime.add(-86_400, :second) |> DateTime.to_naive()
    end
  end

  # (si necesitas también los segundos para el cálculo de rate)
  def window_seconds(w) when is_binary(w) do
    case Regex.run(~r/^\s*(\d+)\s*([mhd])\s*$/i, w) do
      [_, n_str, unit] ->
        n = String.to_integer(n_str)

        case String.downcase(unit) do
          "m" -> n * 60
          "h" -> n * 3_600
          "d" -> n * 86_400
        end

      _ ->
        86_400
    end
  end
end
