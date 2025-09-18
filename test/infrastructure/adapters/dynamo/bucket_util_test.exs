defmodule MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtilTest do
  use ExUnit.Case, async: true

  alias MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtil, as: BU

  test "pk/2 builds partition key with lowercase hex" do
    acc_id = "acc123"
    key_hash = <<0xDE, 0xAD, 0xBE, 0xEF>>
    assert BU.pk(acc_id, key_hash) == "acc:" <> acc_id <> "#key:deadbeef"
  end

  test "sk_bucket/2 for day granularity" do
    ts = ~N[2023-10-10 12:34:56]
    assert BU.sk_bucket(ts, "day") == "ts:20231010"
  end

  test "sk_bucket/2 for hour granularity" do
    ts = ~N[2023-10-10 12:34:56]
    assert BU.sk_bucket(ts, "hour") == "ts:2023101012"
  end

  test "sk_bucket/2 for minute granularity" do
    ts = ~N[2023-10-10 12:34:56]
    assert BU.sk_bucket(ts, "minute") == "ts:202310101234"
  end

  test "sk_bucket/2 for 5m granularity rounds down to nearest multiple of 5" do
    ts = ~N[2023-10-10 12:34:56]
    assert BU.sk_bucket(ts, "5m") == "ts:202310101230"
  end

  test "window_bounds/3 for 2h window with hour granularity" do
    now = ~N[2023-01-02 03:04:05]
    {from, to} = BU.window_bounds(now, "2h", "hour")
    assert from == "ts:2023010201"
    assert to == "ts:2023010203"
  end

  test "window_bounds/3 for 90m window with minute granularity" do
    now = ~N[2023-01-02 03:04:05]
    {from, to} = BU.window_bounds(now, "90m", "minute")
    assert from == "ts:202301020134"
    assert to == "ts:202301020304"
  end

  test "window_bounds/3 fallback on invalid string uses 24h window" do
    now = ~N[2023-01-02 12:00:00]
    {from, to} = BU.window_bounds(now, "invalid", "day")
    assert from == "ts:20230101"
    assert to == "ts:20230102"
  end

  test "now_epoch returns a plausible unix timestamp" do
    n = BU.now_epoch()
    assert is_integer(n)
    # greater than Jan 1, 2000
    assert n > 946_684_800
  end
end

