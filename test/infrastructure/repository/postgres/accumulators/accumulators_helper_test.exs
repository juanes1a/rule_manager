defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelperTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelper, as: H

  describe "normalize_ts/1" do
    test "accepts NaiveDateTime" do
      ndt = ~N[2025-01-02 03:04:05]
      assert {:ok, ^ndt} = H.normalize_ts(ndt)
    end

    test "converts DateTime to NaiveDateTime" do
      dt = DateTime.from_naive!(~N[2025-01-02 03:04:05], "Etc/UTC")
      assert {:ok, ~N[2025-01-02 03:04:05]} = H.normalize_ts(dt)
    end

    test "converts Date to midnight NaiveDateTime" do
      assert {:ok, ~N[2025-01-02 00:00:00]} = H.normalize_ts(~D[2025-01-02])
    end

    test "parses ISO8601 datetime string" do
      assert {:ok, ~N[2025-01-02 03:04:05]} = H.normalize_ts("2025-01-02T03:04:05")
    end

    test "parses ISO8601 DateTime (zulu) string" do
      assert {:ok, ~N[2025-01-02 03:04:05]} = H.normalize_ts("2025-01-02T03:04:05Z")
    end

    test "parses epoch seconds integer" do
      epoch = 1_735_787_245
      expected = epoch |> DateTime.from_unix!() |> DateTime.to_naive()
      assert {:ok, ^expected} = H.normalize_ts(epoch)
    end

    test "returns error for invalid input" do
      assert {:error, :bad_ts} = H.normalize_ts(:bad)
      assert {:error, :bad_ts} = H.normalize_ts("not-a-date")
    end
  end

  describe "truncate_to_gran/2" do
    setup do
      {:ok, ndt: ~N[2025-01-02 03:04:05]}
    end

    test "truncates to day", %{ndt: ndt} do
      assert %NaiveDateTime{hour: 0, minute: 0, second: 0} = H.truncate_to_gran(ndt, "day")
    end

    test "truncates to hour", %{ndt: ndt} do
      res = H.truncate_to_gran(ndt, "hour")
      assert res.hour == 3 and res.minute == 0 and res.second == 0
    end

    test "truncates to minute", %{ndt: ndt} do
      res = H.truncate_to_gran(ndt, "minute")
      assert res.minute == 4 and res.second == 0
    end

    test "unknown granularity returns input", %{ndt: ndt} do
      assert H.truncate_to_gran(ndt, "sec") == ndt
    end
  end

  describe "shift_window/2" do
    test "shifts minutes, hours, and days" do
      now = DateTime.from_unix!(1_735_787_245) # 2025-01-02 03:04:05Z
      assert {:ok, dt_m} = H.shift_window(now, "5m")
      assert DateTime.diff(now, dt_m, :second) == 300

      assert {:ok, dt_h} = H.shift_window(now, "2h")
      assert DateTime.diff(now, dt_h, :second) == 7200

      assert {:ok, dt_d} = H.shift_window(now, "1d")
      assert DateTime.diff(now, dt_d, :second) == 86_400
    end

    test "invalid window returns error" do
      now = DateTime.utc_now()
      assert {:error, :bad_window} = H.shift_window(now, "7x")
    end
  end

  describe "normalize_key/2" do
    test "keeps only defined dimensions in order" do
      map = %{"a" => 1, "b" => 2, "c" => 3}
      dims = ["b", "c"]
      assert H.normalize_key(map, dims) == %{"b" => 2, "c" => 3}
    end
  end
end
