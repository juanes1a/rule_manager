defmodule MsEvaluateRules.Domain.UseCases.EvaluatorUseCaseTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Domain.UseCases.EvaluatorUseCase
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository

  describe "evaluate/4 - happy path with score mapping" do
    test "accumulates effects, halts on stop_on_match, maps thresholds" do
      bundle = %{
        signature: %{id: "sig-1"},
        ruleset: %{version: 3},
        rules: [
          %{
            name: "r1",
            priority: 1,
            enabled: true,
            condition: %{"field" => "age", "op" => ">=", "type" => "number", "value" => 5},
            effects: [
              %{"type" => "add_score", "value" => 6},
              %{"type" => "set_label", "value" => "maybe"},
              %{"type" => "flag", "value" => "age_ok"}
            ],
            stop_on_match: false
          },
          %{
            name: "r2",
            priority: 2,
            enabled: true,
            condition: %{"field" => "country", "op" => "=", "type" => "string", "value" => "CO"},
            effects: [
              %{"type" => "add_score", "value" => 5},
              %{"type" => "flag", "value" => "co"}
            ],
            stop_on_match: true
          },
          %{
            name: "r3",
            priority: 3,
            enabled: true,
            condition: %{"field" => "age", "op" => ">", "type" => "number", "value" => 100},
            effects: [%{"type" => "set_label", "value" => "should_not"}],
            stop_on_match: false
          }
        ],
        config: %{
          output_mode: :score,
          aggregation: :sum,
          mapping: %{
            "thresholds" => [
              %{"gte" => 10, "result" => true, "label" => "HIGH"},
              %{"gte" => 5, "result" => false, "label" => "MED"}
            ],
            "default" => %{"result" => false, "label" => "LOW"}
          },
          field_defs: %{
            "age" => %{"type" => "number"},
            "country" => %{"type" => "string"}
          }
        }
      }

      with_mock QueryManagerRepository, [
                  get_runtime_bundle_single_query: fn _app, _sig -> {:ok, bundle} end
                ] do
        assert {:ok, eval} =
                 EvaluatorUseCase.evaluate("app1", "sig1", %{"age" => "7", "country" => "CO"})

        # score 6 + 5 = 11, bucket gte 10 -> true/HIGH
        assert eval.version == 3
        assert eval.matched_rules == ["r1", "r2"]
        assert eval.result.score == 11
        assert eval.result.boolean == true
        assert eval.result.string == "HIGH"
        assert Enum.sort(eval.reasons) == ["age_ok", "co"]
      end
    end
  end

  describe "evaluate/4 - boolean output" do
    test "boolean is false when score is 0" do
      bundle = %{
        signature: %{id: "sig-2"},
        ruleset: %{version: 1},
        rules: [
          %{
            name: "r1",
            priority: 1,
            enabled: true,
            condition: %{"field" => "flag", "op" => "=", "type" => "boolean", "value" => false},
            effects: [],
            stop_on_match: false
          }
        ],
        config: %{
          output_mode: :boolean,
          aggregation: :any_true,
          mapping: %{},
          field_defs: %{"flag" => %{"type" => "boolean"}}
        }
      }

      with_mock QueryManagerRepository, [
                  get_runtime_bundle_single_query: fn _app, _sig -> {:ok, bundle} end
                ] do
        assert {:ok, eval} =
                 EvaluatorUseCase.evaluate("app1", "sig1", %{"flag" => false})

        assert eval.result.boolean == false
        assert eval.result.score == 0
        assert eval.result.string == nil
      end
    end

    test "boolean is true when score > 0" do
      bundle = %{
        signature: %{id: "sig-3"},
        ruleset: %{version: 2},
        rules: [
          %{
            name: "r1",
            priority: 1,
            enabled: true,
            condition: %{"field" => "n", "op" => ">", "type" => "number", "value" => 0},
            effects: [%{"type" => "add_score", "value" => 1}],
            stop_on_match: false
          }
        ],
        config: %{
          output_mode: :boolean,
          aggregation: :any_true,
          mapping: %{},
          field_defs: %{"n" => %{"type" => "number"}}
        }
      }

      with_mock QueryManagerRepository, [
                  get_runtime_bundle_single_query: fn _app, _sig -> {:ok, bundle} end
                ] do
        assert {:ok, eval} =
                 EvaluatorUseCase.evaluate("app1", "sig1", %{"n" => 2})

        assert eval.result.boolean == true
        assert eval.result.score == 1
      end
    end
  end

  describe "evaluate/4 - string output" do
    test "uses final label and reasons" do
      bundle = %{
        signature: %{id: "sig-5"},
        ruleset: %{version: 4},
        rules: [
          %{
            name: "r_label",
            priority: 1,
            enabled: true,
            condition: %{"field" => "x", "op" => "=", "type" => "number", "value" => 1},
            effects: [%{"type" => "set_label", "value" => "LABEL"}, %{"type" => "flag", "value" => "reason1"}],
            stop_on_match: false
          }
        ],
        config: %{output_mode: :string, aggregation: :sum, mapping: %{}, field_defs: %{"x" => %{"type" => "number"}}}
      }

      with_mock QueryManagerRepository, [
                  get_runtime_bundle_single_query: fn _app, _sig -> {:ok, bundle} end
                ] do
        assert {:ok, eval} = EvaluatorUseCase.evaluate("app", "sig", %{"x" => 1})
        assert eval.result.string == "LABEL"
        assert Enum.member?(eval.reasons, "reason1")
      end
    end
  end

  describe "evaluate/4 - dynamic value functions (now/days_ago/hours_ago)" do
    test "date now equals today's date" do
      bundle = %{
        signature: %{id: "sig-6"},
        ruleset: %{version: 9},
        rules: [
          %{
            name: "r_now",
            priority: 1,
            enabled: true,
            condition: %{"field" => "today", "op" => "=", "type" => "date", "value" => %{"fn" => "now"}},
            effects: [%{"type" => "add_score", "value" => 1}],
            stop_on_match: false
          }
        ],
        config: %{output_mode: :boolean, aggregation: :sum, mapping: %{}, field_defs: %{"today" => %{"type" => "date"}}}
      }

      with_mock QueryManagerRepository, [get_runtime_bundle_single_query: fn _, _ -> {:ok, bundle} end] do
        assert {:ok, eval} = EvaluatorUseCase.evaluate("app", "sig", %{"today" => Date.utc_today()})
        assert eval.result.score == 1
      end
    end

    test "datetime is >= hours_ago(1)" do
      bundle = %{
        signature: %{id: "sig-7"},
        ruleset: %{version: 10},
        rules: [
          %{
            name: "r_ago",
            priority: 1,
            enabled: true,
            condition: %{"field" => "now", "op" => ">=", "type" => "datetime", "value" => %{"fn" => "hours_ago", "args" => [1]}},
            effects: [%{"type" => "add_score", "value" => 1}],
            stop_on_match: false
          }
        ],
        config: %{output_mode: :boolean, aggregation: :sum, mapping: %{}, field_defs: %{"now" => %{"type" => "datetime"}}}
      }

      with_mock QueryManagerRepository, [get_runtime_bundle_single_query: fn _, _ -> {:ok, bundle} end] do
        assert {:ok, eval} = EvaluatorUseCase.evaluate("app", "sig", %{"now" => NaiveDateTime.utc_now()})
        assert eval.result.score == 1
      end
    end
  end
  describe "evaluate/4 - error mapping" do
    test "returns {:error, :could_not_evaluate} when repository fails" do
      with_mock QueryManagerRepository, [
                  get_runtime_bundle_single_query: fn _app, _sig -> {:error, :not_found} end
                ] do
        assert {:error, :could_not_evaluate} ==
                 EvaluatorUseCase.evaluate("app1", "sig1", %{"x" => 1})
      end
    end
  end

  describe "evaluate/4 - condition missing/exists handling" do
    test "op missing returns true for absent field; exists false" do
      bundle = %{
        signature: %{id: "sig-4"},
        ruleset: %{version: 1},
        rules: [
          %{
            name: "r_missing",
            priority: 1,
            enabled: true,
            condition: %{"field" => "absent", "op" => "missing", "type" => "string"},
            effects: [%{"type" => "add_score", "value" => 2}],
            stop_on_match: false
          },
          %{
            name: "r_exists",
            priority: 2,
            enabled: true,
            condition: %{"field" => "absent", "op" => "exists", "type" => "string"},
            effects: [%{"type" => "add_score", "value" => 5}],
            stop_on_match: false
          }
        ],
        config: %{
          output_mode: :boolean,
          aggregation: :sum,
          mapping: %{},
          field_defs: %{"present" => %{"type" => "string"}}
        }
      }

      with_mock QueryManagerRepository, [
                  get_runtime_bundle_single_query: fn _app, _sig -> {:ok, bundle} end
                ] do
        assert {:ok, eval} =
                 EvaluatorUseCase.evaluate("app1", "sig1", %{"present" => "x"})

        # only r_missing applies (2), r_exists does not
        assert eval.result.score == 2
        assert eval.matched_rules == ["r_missing"]
      end
    end
  end
end
