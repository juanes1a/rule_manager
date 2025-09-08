defmodule MsEvaluateRules.Domain.UseCases.AccumulatorUseCase do
  @moduledoc "Resolver de acumuladores definidos en field_defs.acc_ref."
  @accumulators_query_repository Application.compile_env(
                                   :ms_evaluate_rules,
                                   :accumulators_query_repository
                                 )
  alias Decimal, as: D

  @doc """
  Inserta en el mapa `typed_input` los campos virtuales definidos con `acc_ref`.
  Usa `raw_input` para leer las dimensiones (evita problemas si la coerción cambió tipos).
  """
  @spec enrich_with_accs(map(), map(), map()) :: map()
  def enrich_with_accs(typed_input, field_defs, raw_input) when is_map(field_defs) do
    Enum.reduce(field_defs, typed_input, fn
      # 1) ratio = num/den (ambos acc_ref); soporta "default" si den=0
      {field, %{"compute" => "ratio", "num" => n, "den" => d} = spec}, acc_map ->
        num = read_acc_float(n["acc_ref"], raw_input)
        den = read_acc_float(d["acc_ref"], raw_input)
        default = Map.get(spec, "default", 0.0)
        Map.put(acc_map, field, if(den == 0.0, do: default, else: num / den))

      # 2) rate = sum(window) / duración (per: "second"|"minute"|"hour"|"day")
      {field, %{"compute" => "rate", "acc_ref" => ar} = spec}, acc_map ->
        per =
          spec
          |> Map.get("per", "second")
          |> to_per_atom()

        dec =
          @accumulators_query_repository.read_rate(ar["name"], key_from(ar, raw_input), %{
            window: Map.get(ar, "window", "24h"),
            per: per
          })

        Map.put(acc_map, field, to_float(dec))

      # 3) extreme: max/min en la ventana
      {field, %{"compute" => "extreme", "op" => op, "acc_ref" => ar}}, acc_map ->
        fun = if op == "min", do: &@accumulators_query_repository.read_min/3, else: &@accumulators_query_repository.read_max/3

        dec = fun.(ar["name"], key_from(ar, raw_input), %{window: Map.get(ar, "window", "7d")})
        Map.put(acc_map, field, to_float(dec))

      # 4) time_since_last: segundos desde el último evento; si no hay, valor grande por defecto
      {field, %{"compute" => "time_since_last", "acc_ref" => ar} = spec}, acc_map ->
        default = Map.get(spec, "default", 9_223_372_036_854_775_807)

        secs =
          @accumulators_query_repository.read_time_since_last(ar["name"], key_from(ar, raw_input))

        val =
          case secs do
            :infinite -> default
            n when is_integer(n) and n >= 0 -> n
            _ -> default
          end

        Map.put(acc_map, field, val)

      # 5) acc_ref (como hoy)
      {field, %{"acc_ref" => ar}}, acc_map ->
        Map.put(acc_map, field, read_acc_float(ar, raw_input))

      _other, acc_map ->
        acc_map
    end)
  end

  def enrich_with_accs(typed_input, _field_defs, _raw_input), do: typed_input

  defp safe_read(name, key_map, window) do
    try do
      {:ok, @accumulators_query_repository.read(name, key_map, %{window: window})}
    rescue
      _ -> {:error, :read_failed}
    end
  end

  # Lee un acc_ref y devuelve float (0.0 si falla)
  defp read_acc_float(%{"name" => name} = ar, raw_input) do
    window = Map.get(ar, "window", "7d")
    key_map = key_from(ar, raw_input)

    case safe_read(name, key_map, window) do
      {:ok, %D{} = dec} -> D.to_float(dec)
      _ -> 0.0
    end
  end

  # Construye el key_map desde los campos declarados en acc_ref.key
  defp key_from(ar, raw_input) do
    ar["key"]
    |> List.wrap()
    |> Enum.map(&{&1, Map.get(raw_input, &1)})
    |> Enum.into(%{})
  end

  defp to_float(%D{} = d), do: D.to_float(d)
  defp to_float(n) when is_number(n), do: n
  defp to_float(_), do: 0.0

  defp to_per_atom("second"), do: :second
  defp to_per_atom("minute"), do: :minute
  defp to_per_atom("hour"), do: :hour
  defp to_per_atom("day"), do: :day
  defp to_per_atom(_), do: :second
end
