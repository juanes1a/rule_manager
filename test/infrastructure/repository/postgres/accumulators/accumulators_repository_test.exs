defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsRepositoryTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    AccumulatorsRepository,
    Accumulator,
    Bucket
  }

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  @acc %Accumulator{
    id: Ecto.UUID.generate(),
    name: "login_events",
    status: :active,
    bucket_gran: :day,
    dimensions: ["user_id", "country"]
  }

  describe "ingest/4" do
    test "inserts or increments bucket on conflict" do
      with_mocks [
        {Repo, [], [
          get_by: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          insert:
            fn %Ecto.Changeset{data: %Bucket{}} = _changeset, opts ->
              assert Keyword.get(opts, :conflict_target) == [:accumulator_id, :bucket_start, :key_hash]
              assert Keyword.has_key?(opts, :on_conflict)
              {:ok, :ok}
            end
        ]}
      ] do
        assert :ok ==
                 AccumulatorsRepository.ingest(
                   "login_events",
                   %{"user_id" => 1, "country" => "CO", "ignored" => 123},
                   ~U[2025-01-02 03:04:05Z],
                   2
                 )
      end
    end

    test "returns error when accumulator missing" do
      with_mock Repo, get_by: fn Accumulator, [name: "missing", status: :active] -> nil end do
        assert {:error, :acc_not_found} =
                 AccumulatorsRepository.ingest("missing", %{}, ~U[2025-01-02 00:00:00Z], 1)
      end
    end

    test "returns error when ts invalid" do
      with_mock Repo, get_by: fn Accumulator, [name: "login_events", status: :active] -> @acc end do
        assert {:error, :bad_ts} = AccumulatorsRepository.ingest("login_events", %{}, :bad, 1)
      end
    end

    test "propagates Repo.insert error" do
      with_mocks [
        {Repo, [], [
          get_by: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          insert: fn _cs, _opts -> {:error, :db_error} end
        ]}
      ] do
        assert {:error, :db_error} =
                 AccumulatorsRepository.ingest("login_events", %{}, ~U[2025-01-02 00:00:00Z], 1)
      end
    end
  end

  describe "read/3" do
    test "reads sum over window using key hash" do
      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          one: fn _query -> Decimal.new(12) end
        ]}
      ] do
        result =
          AccumulatorsRepository.read(
            "login_events",
            %{"user_id" => 1, "country" => "CO", "ignored" => 9},
            %{window: "7d", now?: ~U[2025-01-02 12:00:00Z]}
          )

        assert %Decimal{} = result
        assert Decimal.eq?(result, Decimal.new(12))
      end
    end
  end
end
