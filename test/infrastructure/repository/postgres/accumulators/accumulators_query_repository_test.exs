defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepositoryTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    AccumulatorsQueryRepository,
    Accumulator
  }

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  @acc %Accumulator{
    id: Ecto.UUID.generate(),
    name: "login_events",
    status: :active,
    bucket_gran: :day,
    dimensions: ["user_id", "country"]
  }

  describe "read/3" do
    test "sums values from buckets over window by key hash" do
      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          one: fn _query -> Decimal.new(12) end
        ]}
      ] do
        res = AccumulatorsQueryRepository.read("login_events", %{"user_id" => 1, "country" => "CO"}, %{window: "7d", now?: ~U[2025-01-02 00:00:00Z]})
        assert Decimal.eq?(res, Decimal.new(12))
      end
    end
  end

  describe "read_avg/3" do
    test "divides sum by count and returns 0 when count is 0" do
      counter = :ets.new(:read_calls, [:set, :public])
      :ets.insert(counter, {:n, 0})

      with_mocks [
        {Repo, [], [
          get_by!: fn _schema, _kw -> @acc end,
          one: fn _q ->
            n = case :ets.lookup(counter, :n) do
              [] -> 0
              [{_, v}] -> v
            end
            :ets.insert(counter, {:n, n + 1})
            if n == 0, do: Decimal.new(10), else: Decimal.new(0)
          end
        ]}
      ] do
        assert Decimal.eq?(AccumulatorsQueryRepository.read_avg("sum", "count", %{}, %{window: "7d"}), Decimal.new(0))
      end

      :ets.delete(counter)

      counter2 = :ets.new(:read_calls2, [:set, :public])
      :ets.insert(counter2, {:n, 0})

      with_mocks [
        {Repo, [], [
          get_by!: fn _schema, _kw -> @acc end,
          one: fn _q ->
            n = case :ets.lookup(counter2, :n) do
              [] -> 0
              [{_, v}] -> v
            end
            :ets.insert(counter2, {:n, n + 1})
            if n == 0, do: Decimal.new(10), else: Decimal.new(5)
          end
        ]}
      ] do
        assert Decimal.eq?(AccumulatorsQueryRepository.read_avg("sum", "count", %{}, %{window: "7d"}), Decimal.new(2))
      end
    end
  end

  describe "read_rate/3" do
    test "computes rate per unit: sum * base / secs" do
      with_mocks [
        {Repo, [], [
          get_by!: fn _schema, _kw -> @acc end,
          one: fn _q -> Decimal.new(360) end
        ]}
      ] do
        res = AccumulatorsQueryRepository.read_rate("metric", %{}, %{window: "1h", per: :minute})
        assert Decimal.eq?(res, Decimal.new(6))
      end
    end
  end

  describe "read_max/min/3" do
    test "aggregates correct extreme values" do
      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "metric", status: :active] -> @acc end,
          aggregate: fn _q, agg, _field ->
            case agg do
              :max -> Decimal.new(9)
              :min -> Decimal.new(1)
            end
          end
        ]}
      ] do
        assert Decimal.eq?(AccumulatorsQueryRepository.read_max("metric", %{"user_id" => 1, "country" => "CO"}, %{window: "1d"}), Decimal.new(9))
        assert Decimal.eq?(AccumulatorsQueryRepository.read_min("metric", %{"user_id" => 1, "country" => "CO"}, %{window: "1d"}), Decimal.new(1))
      end
    end

    test "returns 0 when aggregate is nil" do
      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "metric", status: :active] -> @acc end,
          aggregate: fn _q, _agg, _field -> nil end
        ]}
      ] do
        assert Decimal.eq?(AccumulatorsQueryRepository.read_max("metric", %{"user_id" => 1, "country" => "CO"}, %{window: "1d"}), Decimal.new(0))
      end
    end
  end

  describe "read_time_since_last/2" do
    test "returns :infinite when no record and non-negative integer otherwise" do
      now = DateTime.utc_now()
      old = DateTime.add(now, -60, :second)

      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          one: fn _q -> nil end
        ]}
      ] do
        assert :infinite == AccumulatorsQueryRepository.read_time_since_last("login_events", %{"user_id" => 1, "country" => "CO"})
      end

      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          one: fn _q -> DateTime.to_naive(old) end
        ]}
      ] do
        v = AccumulatorsQueryRepository.read_time_since_last("login_events", %{"user_id" => 1, "country" => "CO"})
        assert is_integer(v) and v >= 0
      end
    end

    test "handles DateTime with timezone by shifting to UTC" do
      now = DateTime.utc_now()
      # generate a datetime in a different zone and older by ~2 minutes
      last = now |> DateTime.add(-125, :second) |> DateTime.shift_zone!("Etc/UTC") |> DateTime.shift_zone!("Etc/GMT-2")

      with_mocks [
        {Repo, [], [
          get_by!: fn Accumulator, [name: "login_events", status: :active] -> @acc end,
          one: fn _q -> last end
        ]}
      ] do
        v = AccumulatorsQueryRepository.read_time_since_last("login_events", %{"user_id" => 1, "country" => "CO"})
        assert is_integer(v) and v >= 120
      end
    end
  end
end
