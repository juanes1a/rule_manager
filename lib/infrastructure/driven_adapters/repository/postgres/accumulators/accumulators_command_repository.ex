defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsCommandRepository do
  @moduledoc """
    Ingesta y lectura de acumuladores.
  """

  require Ecto.Query
  import MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelper

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    Accumulator,
    Bucket,
    LastSeen
  }

  @spec ingest(String.t(), map(), DateTime.t(), number()) :: :ok | {:error, term()}
  def ingest(acc_name, key_map, ts, delta) when is_map(key_map) and is_number(delta) do
    with %Accumulator{} = acc <- Repo.get_by(Accumulator, name: acc_name, status: :active),
         {:ok, ts_ndt} <- normalize_ts(ts),
         bucket_start <- truncate_to_gran(ts_ndt, acc.bucket_gran || "day"),
         {:ok, key_json} <- normalize_key(key_map, acc.dimensions),
         key_hash <- :crypto.hash(:sha256, Jason.encode!(key_json)),
         {:ok, _bucket} <- insert_bucket(acc, bucket_start, key_json, key_hash, delta),
         {:ok, _last_seen} <- insert_last_seen(acc.id, key_json, key_hash, ts_ndt) do
      {:ok, true}
    else
      nil -> {:error, :acc_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_bucket(accumulator, bucket_start, key_json, key_hash, delta) do
    params = [
      accumulator.id |> Ecto.UUID.dump!(),
      bucket_start |> DateTime.from_naive!("Etc/UTC"),
      key_json,
      key_hash,
      Decimal.new(delta),
      accumulator.kind |> to_string()
    ]

    sql = """
    INSERT INTO acc_buckets (accumulator_id, bucket_start, key_json, key_hash, value_num, updated_at)
    VALUES ($1, $2, $3::jsonb, $4, $5, now())
    ON CONFLICT (accumulator_id, bucket_start, key_hash)
    DO UPDATE SET
      value_num = CASE $6
        WHEN 'sum'   THEN acc_buckets.value_num + EXCLUDED.value_num
        WHEN 'count' THEN acc_buckets.value_num + EXCLUDED.value_num
        WHEN 'max'   THEN GREATEST(acc_buckets.value_num, EXCLUDED.value_num)
        WHEN 'min'   THEN LEAST(acc_buckets.value_num, EXCLUDED.value_num)
        ELSE acc_buckets.value_num + EXCLUDED.value_num
      END,
      updated_at = now()
    """

    Repo.query(sql, params)
  end

  defp insert_last_seen(accumulator_id, key_json, key_hash, last_update) do
    sql = """
    INSERT INTO acc_last_seen (accumulator_id, key_json, key_hash, last_at, count, updated_at)
    VALUES ($1, $2::jsonb, $3, $4, 1, now())
    ON CONFLICT (accumulator_id, key_hash)
    DO UPDATE SET
      last_at    = GREATEST(acc_last_seen.last_at, EXCLUDED.last_at),
      count      = acc_last_seen.count + 1,
      updated_at = now()
    """

    params = [
      accumulator_id |> Ecto.UUID.dump!,
      key_json,
      key_hash,
      last_update |> DateTime.from_naive!("Etc/UTC")
    ]
    Repo.query(sql, params)
  end
end
