defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelperMoreTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelper, as: H

  test "normalize_per/1 handles atoms, strings, case-insensitive and defaults" do
    assert H.normalize_per(:minute) == :minute
    assert H.normalize_per("MINUTE") == :minute
    assert H.normalize_per("Hour") == :hour
    assert H.normalize_per("day") == :day
    assert H.normalize_per("weeks") == :second
    assert H.normalize_per(123) == :second
  end

  test "window_seconds/1 parses units and falls back to 24h on invalid" do
    assert H.window_seconds("15m") == 900
    assert H.window_seconds("2h") == 7200
    assert H.window_seconds("7d") == 604_800
    assert H.window_seconds(" bad ") == 86_400
  end

  test "shift_window/2 supports flexible formatting and invalid returns error" do
    now = DateTime.utc_now()
    assert {:ok, _} = H.shift_window(now, "3h")
    assert {:error, :bad_window} = H.shift_window(now, "x")
  end

  test "shift_window accepts NaiveDateTime by converting to UTC" do
    now = DateTime.utc_now() |> DateTime.to_naive()
    assert {:ok, _} = H.shift_window(now, "10m")
  end

  test "window_from_now returns NaiveDateTime and falls back on invalid window" do
    good = H.window_from_now("1h")
    assert match?(%NaiveDateTime{}, good)

    bad = H.window_from_now("x")
    assert match?(%NaiveDateTime{}, bad)
    # should be roughly 24h ago vs now
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), bad, :second)
    assert diff in 86_300..86_500
  end
end
