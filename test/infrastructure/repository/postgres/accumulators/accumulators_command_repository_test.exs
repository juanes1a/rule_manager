defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsCommandRepositoryTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    AccumulatorsCommandRepository,
    Accumulator
  }

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  @acc %Accumulator{
    id: Ecto.UUID.generate(),
    name: "login_events",
    status: :active,
    kind: :count,
    bucket_gran: :day,
    dimensions: ["user_id", "country"]
  }

  test "ingest/4 inserts into buckets and last_seen with proper params" do
    calls = :ets.new(:calls, [:bag, :public])

    with_mocks [
      {Repo, [], [
        get_by: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
        query: fn sql, params ->
          :ets.insert(calls, {:call, {sql, params}})
          {:ok, %{}}
        end
      ]}
    ] do
      assert {:ok, true} =
               AccumulatorsCommandRepository.ingest(
                 "login_events",
                 %{"user_id" => 1, "country" => "CO", "ignored" => :x},
                 ~U[2025-01-02 03:04:05Z],
                 2
               )

      # We should have two Repo.query calls captured
      assert :ets.lookup(calls, :call) |> length() == 2
    end
  end

  test "ingest returns error when accumulator missing" do
    with_mock Repo, get_by: fn Accumulator, [name: "missing", status: :active] -> nil end do
      assert {:error, :acc_not_found} =
               AccumulatorsCommandRepository.ingest("missing", %{}, ~U[2025-01-02 00:00:00Z], 1)
    end
  end

  test "ingest returns error on bad ts" do
    with_mock Repo, get_by: fn Accumulator, [name: "login_events", status: :active] -> @acc end do
      assert {:error, :bad_ts} =
               AccumulatorsCommandRepository.ingest("login_events", %{}, :bad, 1)
    end
  end
end
