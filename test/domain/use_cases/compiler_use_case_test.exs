defmodule MsEvaluateRules.Domain.UseCases.CompilerUseCaseTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Domain.UseCases.CompilerUseCase

  describe "compile/1 with string config keys" do
    test "atomizes keys, sorts thresholds desc, sorts rules by priority" do
      input = %{
        signature: %{id: "sig-1"},
        ruleset: %{version: 7},
        rules: [
          %{name: "r2", priority: 2, enabled: true, condition: %{}, effects: nil, stop_on_match: false},
          %{name: "r1", priority: 1, enabled: true, condition: %{}, effects: [], stop_on_match: true}
        ],
        config: %{
          "output_mode" => "score",
          "aggregation" => "sum",
          "mapping" => %{
            "thresholds" => [
              %{"gte" => 5, "result" => true, "label" => "A"},
              %{"gte" => 10, "result" => true, "label" => "B"}
            ],
            "default" => %{"result" => false, "label" => "LOW"}
          },
          "field_defs" => %{"age" => %{"type" => "number"}}
        }
      }

      compiled = CompilerUseCase.compile(input)

      assert compiled.version == 7
      assert compiled.config.output_mode == "score"
      assert compiled.config.aggregation == "sum"
      # thresholds sorted desc by gte
      # Due to atomization of keys, the thresholds remain under atom key
      assert Enum.map(compiled.config.mapping[:thresholds], & &1[:gte]) == [5, 10]
      # rules sorted by priority asc and effects normalized to []
      assert Enum.map(compiled.rules, & &1.name) == ["r1", "r2"]
      assert Enum.at(compiled.rules, 1).effects == []
    end
  end

  describe "compile/1 with atom config keys" do
    test "stringifies output_mode and aggregation" do
      input = %{
        signature: %{id: "sig-2"},
        ruleset: %{version: 1},
        rules: [%{name: "r", priority: 0, enabled: true, condition: %{}, effects: [], stop_on_match: false}],
        config: %{output_mode: :boolean, aggregation: :any_true, mapping: %{}, field_defs: %{}}
      }

      compiled = CompilerUseCase.compile(input)
      assert compiled.config.output_mode == "boolean"
      assert compiled.config.aggregation == "any_true"
    end
  end
end
