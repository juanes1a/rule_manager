defmodule MsEvaluateRules.Domain.UseCases.EvaluatorUseCase do
  @moduledoc """
  Evaluador puro contra un RuleSet compilado.
  Tipos: number, string, boolean, date, datetime, decimal, uuid.
  Operadores: = != > >= < <= in not_in contains starts_with ends_with regex between exists
  **missing length_eq length_gt length_lt length_between**.
  Funciones en valores: **now, days_ago(n), hours_ago(n)**; variables: {"var":"campo"}.
  """
  require Logger

  alias MsEvaluateRules.Domain.UseCases.CompilerUseCase
  alias MsEvaluateRules.Domain.UseCases.AccumulatorUseCase

  import MsEvaluateRules.Domain.UseCases.TypicalCoercionUtil,
    only: [coerce_input: 2, to_number: 1]

  import MsEvaluateRules.Domain.UseCases.ComparatorsUtil, only: [compare: 4]

  @rules_repository Application.compile_env(:ms_evaluate_rules, :rules_repository)

  def evaluate(application, signature, input, opts \\ []) when is_map(input) do
    with {:ok, result} <- @rules_repository.get_runtime_bundle_single_query(application, signature),
         bundle <- CompilerUseCase.compile(result),
         field_defs <- bundle.config.field_defs || %{},
         typed0 <- coerce_input(input, bundle.config[:field_defs] || %{}),
         typed <- AccumulatorUseCase.enrich_with_accs(typed0, field_defs, input) |> IO.inspect(),
         evaluation <- do_eval(bundle, typed, opts) do
      {:ok, evaluation}
    else
      error ->
        Logger.error("Error on evaluation: #{inspect(error)}")
        {:error, :could_not_evaluate}
    end
  end

  defp do_eval(%{rules: rules, config: cfg, version: ver}, input, _opts) do
    {acc, matched} =
      Enum.reduce_while(rules, init_acc(cfg), fn rule, {acc0, matched0} ->
        if rule.enabled && cond_true?(rule.condition, input) do
          acc1 = apply_effects(acc0, rule.effects)
          matched1 = [rule.name | matched0]

          if rule.stop_on_match do
            {:halt, {acc1, matched1}}
          else
            {:cont, {acc1, matched1}}
          end
        else
          {:cont, {acc0, matched0}}
        end
      end)

    result = map_output(acc, cfg)
    Map.merge(result, %{matched_rules: Enum.reverse(matched), version: ver})
  end

  # === Acumulador ===
  defp init_acc(%{aggregation: _}) do
    {%{score: 0, flags: MapSet.new(), label: nil}, []}
  end

  # === Condiciones ===
  defp cond_true?(%{"all" => list}, input), do: Enum.all?(list, &cond_true?(&1, input))
  defp cond_true?(%{"any" => list}, input), do: Enum.any?(list, &cond_true?(&1, input))

  defp cond_true?(%{"field" => f, "op" => op, "type" => t} = p, input) do
    left = Map.get(input, f, :__missing__)
    right_raw = Map.get(p, "value")
    right = value_or_fn(right_raw, t)
    compare(left, op, right, t)
  end

  # === Valores dinámicos / funciones ===
  # se re-resuelve en compare si es needed
  defp value_or_fn(%{"var" => name}, _t), do: Map.get(%{}, name, :__missing__)
  defp value_or_fn(%{"fn" => "now"}, "date"), do: Date.utc_today()
  defp value_or_fn(%{"fn" => "now"}, "datetime"), do: NaiveDateTime.utc_now()

  defp value_or_fn(%{"fn" => "days_ago", "args" => [n]}, "date") when is_integer(n),
    do: Date.add(Date.utc_today(), -n)

  defp value_or_fn(%{"fn" => "hours_ago", "args" => [n]}, "datetime") when is_integer(n),
    do: NaiveDateTime.add(NaiveDateTime.utc_now(), -n * 3600)

  defp value_or_fn(v, _t), do: v

  # === Efectos ===
  defp apply_effects(acc, effects) do
    Enum.reduce(effects, acc, fn
      %{"type" => "add_score", "value" => v}, a ->
        Map.update!(a, :score, &(&1 + to_number(v)))

      %{"type" => "set_label", "value" => lbl}, a ->
        Map.put(a, :label, lbl)

      %{"type" => "flag", "value" => reason}, a ->
        Map.update!(a, :flags, &MapSet.put(&1, reason))

      _, a ->
        a
    end)
  end

  # === Salida ===
  defp map_output(%{score: score, flags: flags, label: label}, %{
         output_mode: "score",
         mapping: %{"thresholds" => th, "default" => defo}
       }) do
    bucket = Enum.find(th, defo, fn %{"gte" => g} -> score >= g end)

    %{
      result: %{
        score: score,
        boolean: Map.get(bucket, "result"),
        string: Map.get(bucket, "label") || label
      },
      reasons: MapSet.to_list(flags)
    }
  end

  defp map_output(%{score: score, flags: flags, label: label}, %{
         output_mode: "boolean"
       }) do
    %{
      result: %{boolean: score > 0, string: label, score: score},
      reasons: MapSet.to_list(flags)
    }
  end

  defp map_output(%{score: score, flags: flags, label: label}, %{
         output_mode: "string"
       }) do
    %{result: %{string: label, score: score}, reasons: MapSet.to_list(flags)}
  end
end
