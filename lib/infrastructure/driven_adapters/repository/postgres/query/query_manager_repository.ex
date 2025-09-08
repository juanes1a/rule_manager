defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository do
  import Ecto.Query, warn: false
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.{ApplicationData, SignatureData, RuleSetData, RuleData}

  @doc """
  Carga signature + ruleset activo + rules habilitadas en una sola consulta.
  Retorna el mismo bundle que Loader.get_runtime_bundle/3.
  """
  def get_runtime_bundle_single_query(app_name, signature_name, at \\ DateTime.utc_now()) do
    query =
      from s in SignatureData,
        join: a  in ApplicationData, on: a.id == s.app_id,
        join: rs in RuleSetData,
          on:
            rs.signature_id == s.id and
            rs.version == s.active_version and
            rs.status  == :published and
            (is_nil(rs.valid_from) or rs.valid_from <= ^at) and
            (is_nil(rs.valid_to)   or rs.valid_to   >  ^at),
        left_join: r in RuleData,
          on:
            r.ruleset_id == rs.id and r.enabled == true and
            (is_nil(r.valid_from) or r.valid_from <= ^at) and
            (is_nil(r.valid_to)   or r.valid_to   >  ^at),
        where:
          a.name == ^app_name and a.status == :active and
          s.name == ^signature_name and s.status == :active,
        order_by: [asc: r.priority],
        select: %{signature: s, ruleset: rs, rule: r}

    rows = Repo.all(query)

    case rows do
      [] ->
        {:error, :not_found}

      list ->
        # Agrupar rules (puede venir nil si no hay reglas activas)
        %{signature: s, ruleset: rs} = hd(list)
        rules =
          list
          |> Enum.flat_map(fn %{rule: r} -> if is_nil(r), do: [], else: [r] end)

        {:ok,
         %{
           signature: s,
           ruleset: rs,
           rules: rules,
           config: %{
             output_mode: s.output_mode,
             aggregation: s.aggregation,
             mapping: s.mapping,
             field_defs: s.field_defs
           }
         }}
    end
  end
end
