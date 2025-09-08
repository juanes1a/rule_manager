defmodule MsEvaluateRules.Domain.UseCases.CompilerUseCase do

  @moduledoc """
  Normaliza y 'compila' el bundle cargado desde la BD para ejecución rápida.
  """
  def compile(%{
        signature: s,
        ruleset: rs,
        rules: rules,
        config: %{"output_mode" => _} = cfg
      }) do
    compile(%{signature: s, ruleset: rs, rules: rules, config: atomize_keys(cfg)})
  end

  def compile(%{
        signature: s,
        ruleset: rs,
        rules: rules,
        config: %{output_mode: om, aggregation: aggr, mapping: mapping, field_defs: field_defs}
      }) do
    mapping_norm =
      mapping
      |> Map.update("thresholds", [], fn th ->
        Enum.sort_by(th, &Map.get(&1, "gte", 0), :desc)
      end)

    %{
      signature_id: s.id,
      version: rs.version,
      config: %{
        output_mode: to_string(om),
        aggregation: to_string(aggr),
        mapping: mapping_norm,
        field_defs: field_defs
      },
      rules:
        rules
        |> Enum.sort_by(& &1.priority)
        |> Enum.map(fn r ->
          %{
            name: r.name,
            priority: r.priority,
            enabled: r.enabled,
            condition: r.condition,
            effects: r.effects || [],
            stop_on_match: r.stop_on_match
          }
        end)
    }
  end

  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {if(is_binary(k), do: String.to_atom(k), else: k), atomize_keys(v)}
    end)
    |> Map.new()
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(other), do: other

end
