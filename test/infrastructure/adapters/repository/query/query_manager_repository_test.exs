defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepositoryTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Query.QueryManagerRepository
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.{
    Repo,
    SignatureData,
    RuleSetData,
    RuleData
  }

  @fixed_now ~U[2024-01-02 03:04:05Z]

  describe "get_runtime_bundle_single_query/3" do
    test "returns :not_found when no rows" do
      with_mock Repo, [all: fn _query -> [] end] do
        assert {:error, :not_found} ==
                 QueryManagerRepository.get_runtime_bundle_single_query(
                   "app-x",
                   "sig-x",
                   @fixed_now
                 )
      end
    end

    test "returns bundle with empty rules when rule is nil" do
      s = %SignatureData{
        name: "sig-a",
        output_mode: :score,
        aggregation: :sum,
        mapping: %{a: 1},
        field_defs: %{f1: :integer}
      }

      rs = %RuleSetData{version: 1, status: :published}

      rows = [%{signature: s, ruleset: rs, rule: nil}]

      with_mock Repo, [all: fn _query -> rows end] do
        assert {:ok, %{signature: ^s, ruleset: ^rs, rules: [], config: config}} =
                 QueryManagerRepository.get_runtime_bundle_single_query(
                   "app-a",
                   "sig-a",
                   @fixed_now
                 )

        assert config == %{
                 output_mode: :score,
                 aggregation: :sum,
                 mapping: %{a: 1},
                 field_defs: %{f1: :integer}
               }
      end
    end

    test "returns bundle with aggregated rules in order" do
      s = %SignatureData{
        name: "sig-b",
        output_mode: :boolean,
        aggregation: :any_true,
        mapping: %{},
        field_defs: %{}
      }

      rs = %RuleSetData{version: 2, status: :published}

      r1 = %RuleData{name: "r-1", priority: 1}
      r2 = %RuleData{name: "r-2", priority: 2}

      rows = [
        %{signature: s, ruleset: rs, rule: r1},
        %{signature: s, ruleset: rs, rule: r2}
      ]

      with_mock Repo, [all: fn _query -> rows end] do
        assert {:ok, %{signature: ^s, ruleset: ^rs, rules: [^r1, ^r2], config: config}} =
                 QueryManagerRepository.get_runtime_bundle_single_query(
                   "app-b",
                   "sig-b",
                   @fixed_now
                 )

        assert config.output_mode == :boolean
        assert config.aggregation == :any_true
      end
    end
  end
end

