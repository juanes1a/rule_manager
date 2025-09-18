defmodule MsEvaluateRules.Domain.UseCases.AccumulatorUseCase do
  @moduledoc "Resolver de acumuladores definidos en field_defs.acc_ref."
  @accumulators_query_repository Application.compile_env(
                                   :ms_evaluate_rules,
                                   :accumulators_query_repository
                                 )
  @bucket_query_repository Application.compile_env(:ms_evaluate_rules, :bucket_query_repository)

  @moduledoc "Enriquecimiento desde Dynamo (sum, ratio, rate, extreme, time_since_last)."
require Logger

  # ============ API ============
  @doc """
  Enriquecer un mapa `typed_input` con campos descritos en `field_defs` usando `raw_input` (para keys).
  field_defs soporta:
    - %{"acc_ref" => %{name, window?, key?}}
    - %{"compute" => "ratio" | "rate" | "extreme" | "time_since_last", ...}
  """
  def enrich_with_accs(typed_input, field_defs, raw_input) when is_map(field_defs) do
    Enum.reduce(field_defs, typed_input, fn
      {field, %{"compute" => "ratio", "num" => num_spec, "den" => den_spec} = spec}, acc_map ->
        default = Map.get(spec, "default", 0.0)
        v = read_ratio(num_spec, den_spec, raw_input, default)
        Map.put(acc_map, field, v)

      {field, %{"compute" => "rate", "acc_ref" => acc_spec} = spec}, acc_map ->
        per = (spec["per"] || "second") |> String.downcase()
        v = read_rate(acc_spec, raw_input, per)
        Map.put(acc_map, field, v)

      {field, %{"compute" => "extreme", "op" => op, "acc_ref" => acc_spec}}, acc_map ->
        which =
          case String.downcase(op || "") do
            "max" -> :max
            "min" -> :min
            _ -> :max
          end

        v = read_extreme(acc_spec, raw_input, which)
        Map.put(acc_map, field, v)

      {field, %{"compute" => "time_since_last", "acc_ref" => acc_spec} = spec}, acc_map ->
        default = Map.get(spec, "default", 0)
        v = read_time_since_last(acc_spec, raw_input, default)
        Map.put(acc_map, field, v)

      {field, %{"acc_ref" => acc_spec}}, acc_map ->
        v = read_sum(acc_spec, raw_input)
        Map.put(acc_map, field, v)

      _other, acc_map ->
        acc_map
    end)
  end

  # ============ READ HELPERS (Dynamo) ============

  # Lee suma (o count) en ventana. Usa window/gran del acumulador si no se especifican.
  defp read_sum(%{"name" => name} = ref, raw) do
    with {:ok, defn} <- get_acc_def(name),
         {:ok, key_hash} <- key_hash(defn, ref, raw),
         v when is_number(v) <-
           @bucket_query_repository.sum_window(defn, key_hash, ref) do
      v
    else
      _ -> 0.0
    end
  end

  # ratio = sum(num) / sum(den) en sus ventanas respectivas
  defp read_ratio(num_ref, den_ref, raw, default) do
    num = read_sum(num_ref["acc_ref"], raw)
    den = read_sum(den_ref["acc_ref"], raw)
    if den == 0 or den == 0.0, do: default, else: num / den
  end

  # rate = sum(count)/window_secs (opcionalmente escalar por :minute/:hour)
  defp read_rate(%{"name" => _} = ref, raw, per_unit) do
    sum = read_sum(ref, raw)
    secs = window_secs(ref["window"])
    base = if secs <= 0, do: 0.0, else: sum / secs

    case String.downcase(per_unit || "second") do
      "second" -> base
      "minute" -> base * 60.0
      "hour" -> base * 3_600.0
      _ -> base
    end
  end

  defp read_extreme(%{"name" => name} = ref, raw, which) when which in [:max, :min] do
    with {:ok, defn} <- get_acc_def(name),
         {:ok, key_hash} <- key_hash(defn, ref, raw),
         v when is_number(v) <-
           @bucket_query_repository.extreme_window(
             defn,
             key_hash,
             ref,
             which
           ) do
      v
    else
      _ -> 0.0
    end
  end

  defp read_time_since_last(%{"name" => name} = ref, raw, default) do
    with {:ok, defn} <- get_acc_def(name),
         {:ok, key_hash} <- key_hash(defn, ref, raw),
         v <- @bucket_query_repository.time_since_last(defn.id, key_hash) do
      case v do
        :infinite -> default
        n when is_integer(n) and n >= 0 -> n
        n when is_integer(n) and n < 0 -> 0
        _ -> default
      end
    else
      _ -> default
    end
  end

  # ============ UTIL ============

  # Trae definición del acumulador (nombre único, activo)
  defp get_acc_def(name) when is_binary(name) do
    case @accumulators_query_repository.get_accumulator_definition(name) do
      {:ok, defn} -> {:ok, defn}
      error ->
        Logger.error("Accumulator not found: #{error}")
        {:error, :not_found}
    end
  end

  # Construye key_json y sha256(key_json) usando dimensions del defn o "key" del ref
  # - Si el ref define "key": se usa esa lista para tomar valores de raw (override)
  # - Si no: se usan las dimensions del acumulador
  defp key_hash(defn, ref, raw) do
    # override opcional en el acc_ref
    keys = List.wrap(ref["key"])

    dims =
      case keys do
        [] -> defn.dimensions || []
        list when is_list(list) -> list
      end

    with {:ok, key_json} <- normalize_key(raw, dims) do
      {:ok, :crypto.hash(:sha256, Jason.encode!(key_json))}
    else
      _ -> {:error, :bad_key}
    end
  end

  defp window_secs(w) do
    w = (w || "24h") |> String.trim()

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

  def normalize_key(map, dims) do
    {
      :ok,
      dims |> Enum.map(&{&1, Map.get(map, &1)}) |> Enum.into(%{})
    }
  end

end
