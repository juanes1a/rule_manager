defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepositorySmokeTest do
  use ExUnit.Case, async: true

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    AccumulatorsQueryRepository,
    Accumulator
  }
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  test "get_accumulator_definition/1 returns {:ok, defn} when found" do
    defn = %Accumulator{id: Ecto.UUID.generate(), name: "acc", status: :active}

    with_mock Repo, get_by: fn Accumulator, [name: "acc", status: :active] -> defn end do
      assert {:ok, ^defn} = AccumulatorsQueryRepository.get_accumulator_definition("acc")
    end
  end

  test "get_accumulator_definition/1 returns {:error, :not_found} when nil" do
    with_mock Repo, get_by: fn Accumulator, [name: "missing", status: :active] -> nil end do
      assert {:error, :not_found} = AccumulatorsQueryRepository.get_accumulator_definition("missing")
    end
  end
end

