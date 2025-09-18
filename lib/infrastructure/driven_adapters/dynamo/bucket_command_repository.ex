defmodule MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketCommandRepository do

  require MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtil
  import MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtil
  alias ExAws.Dynamo


  def sk_last, do: "last"

  # === Ingest: SUM / COUNT ===
  # kind = "sum" | "count"
  def add!(table, acc_id, key_hash, ts_naive, delta, kind \\ "sum", opts \\ []) do
    gran = Keyword.get(opts, :gran, @gran_default)
    key  = %{"pk" => pk(acc_id, key_hash), "sk" => sk_bucket(ts_naive, gran)}

    req =
      Dynamo.update_item(
        table,
        key,
        update_expression: "SET #u = :now, #k = if_not_exists(#k, :kind) ADD #v :d",
        expression_attribute_names: %{"#v" => "value_num", "#u" => "updated_at", "#k" => "kind"},
        expression_attribute_values: %{"d" => delta, "now" => now_epoch(), "kind" => kind}
      )

    ExAws.request!(req)
    {:ok, true}
  end

  # === Ingest: MAX ===
  def max!(table, acc_id, key_hash, ts_naive, value, opts \\ []) do
    gran = Keyword.get(opts, :gran, @gran_default)
    key = %{"pk" => pk(acc_id, key_hash), "sk" => sk_bucket(ts_naive, gran)}

    req =
      Dynamo.update_item(
        table,
        key,
        update_expression: "SET #v = :val, #u = :now, #k = if_not_exists(#k, :kind)",
        condition_expression: "attribute_not_exists(#v) OR :val > #v",
        expression_attribute_names: %{"#v" => "value_num", "#u" => "updated_at", "#k" => "kind"},
        expression_attribute_values: %{"val" => value, "now" => now_epoch(), "kind" => "max"}
      )

    try do
      ExAws.request!(req)
      {:ok, true}
    rescue
      ex in ExAws.Error ->
        if String.contains?(inspect(ex), "ConditionalCheckFailed") do
          {:ok, true}
        else
          reraise ex, __STACKTRACE__
        end
    end
  end

  # === Ingest: MIN ===
  def min!(table, acc_id, key_hash, ts_naive, value, opts \\ []) do
    gran = Keyword.get(opts, :gran, @gran_default)
    key  = %{"pk" => pk(acc_id, key_hash), "sk" => sk_bucket(ts_naive, gran)}

    req =
      Dynamo.update_item(
        table,
        key,
        update_expression: "SET #v = :val, #u = :now, #k = if_not_exists(#k, :kind)",
        condition_expression: "attribute_not_exists(#v) OR :val < #v",
        expression_attribute_names: %{"#v" => "value_num", "#u" => "updated_at", "#k" => "kind"},
        expression_attribute_values: %{"val" => value, "now" => now_epoch(), "kind" => "min"}
      )

    try do
      ExAws.request!(req)
      {:ok, true}
    rescue
      ex in ExAws.Error ->
        if String.contains?(inspect(ex), "ConditionalCheckFailed") do
          {:ok, true}
        else
          reraise ex, __STACKTRACE__
        end
    end
  end

  # === Ingest: LAST SEEN ===
  def last_seen!(table, acc_id, key_hash, ts_naive) do
    key = %{"pk" => pk(acc_id, key_hash), "sk" => sk_last()}
    ts = DateTime.from_naive!(ts_naive, "Etc/UTC") |> DateTime.to_unix()

    req =
      Dynamo.update_item(
        table,
        key,
        update_expression: "SET #l = :ts, #u = :now ADD #c :one",
        condition_expression: "attribute_not_exists(#l) OR :ts > #l",
        expression_attribute_names: %{"#l" => "last_at", "#u" => "updated_at", "#c" => "count"},
        expression_attribute_values: %{"ts" => ts, "now" => now_epoch(), "one" => 1}
      )

    try do
      ExAws.request!(req)
      {:ok, true}
    rescue
      ex in ExAws.Error ->
        if String.contains?(inspect(ex), "ConditionalCheckFailed") do
          {:ok, true}
        else
          reraise ex, __STACKTRACE__
        end
    end
  end
end
