defmodule MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtil do
  # "day" | "hour" | "minute" | "5m"
  @gran_default "hour"

  # --- CLAVES ---
  def pk(acc_id, key_hash_bin),
    do: "acc:" <> acc_id <> "#key:" <> Base.encode16(key_hash_bin, case: :lower)


  def bounds(ref, defn) do
    gran = ref["gran"] || defn.bucket_gran || "hour"
    window = ref["window"] || default_window_for(gran)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    window_bounds(now, window, gran)
  end

  # Granularidad variable
  def sk_bucket(%NaiveDateTime{} = ts, gran \\ @gran_default) do
    dt = DateTime.from_naive!(ts, "Etc/UTC") |> DateTime.truncate(:second)

    case gran do
      "day" ->
        "ts:" <> Calendar.strftime(dt, "%Y%m%d")

      "hour" ->
        "ts:" <> Calendar.strftime(dt, "%Y%m%d%H")

      "minute" ->
        "ts:" <> Calendar.strftime(dt, "%Y%m%d%H%M")

      "5m" ->
        m = div(dt.minute, 5) * 5
        dt2 = %{dt | minute: m, second: 0}

        "ts:" <>
          Calendar.strftime(dt2, "%Y%m%d%H") <>
          String.pad_leading(Integer.to_string(m), 2, "0")

      _ ->
        "ts:" <> Calendar.strftime(dt, "%Y%m%d%H")
    end
  end

  # Ventana arbitraria (p. ej. "24h", "7d", "90m") y gran deseada
  def window_bounds(%NaiveDateTime{} = now, window, gran \\ @gran_default) do
    secs =
      case Regex.run(~r/^\s*(\d+)\s*([mhd])\s*$/i, window) do
        [_, n, u] ->
          n = String.to_integer(n)

          case String.downcase(u) do
            "m" -> n * 60
            "h" -> n * 3600
            "d" -> n * 86400
          end

        _ ->
          86400
      end

    to_dt = DateTime.from_naive!(now, "Etc/UTC")
    from_dt = DateTime.add(to_dt, -secs, :second)

    from_sk = sk_bucket(DateTime.to_naive(from_dt), gran)
    to_sk = sk_bucket(DateTime.to_naive(to_dt), gran)
    {from_sk, to_sk}
  end

  def now_epoch, do: DateTime.utc_now() |> DateTime.to_unix()

  defp default_window_for("day"), do: "7d"
  defp default_window_for("hour"), do: "24h"
  defp default_window_for("minute"), do: "90m"
  defp default_window_for("5m"), do: "90m"
  defp default_window_for(_), do: "24h"


end
