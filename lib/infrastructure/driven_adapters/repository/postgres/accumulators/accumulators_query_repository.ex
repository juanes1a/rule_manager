defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsQueryRepository do
  import Ecto.Query
  import MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.AccumulatorsHelper

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Repo

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.{
    Accumulator,
    Bucket,
    LastSeen
  }

  alias Decimal, as: D

  @spec read(String.t(), map(), %{window: String.t(), now?: DateTime.t() | nil}) :: Decimal.t()
  def read(acc_name, key_map, opts \\ %{window: "7d", now?: nil}) do
    now = Map.get(opts, :now?) || DateTime.utc_now()

    %Accumulator{} =
      acc = Repo.get_by!(Accumulator, name: acc_name, status: :active)

    {:ok, from_ts} = shift_window(now, opts.window)

    {:ok, key_json} = normalize_key(key_map, acc.dimensions)
    key_hash = :crypto.hash(:sha256, Jason.encode!(key_json))

    query =
      from(b in Bucket,
        where:
          b.accumulator_id == ^acc.id and b.key_hash == ^key_hash and b.bucket_start >= ^from_ts,
        select: coalesce(sum(b.value_num), 0)
      )

    Repo.one(query) |> IO.inspect()
  end

  # AVG = sum / count
  def read_avg(name_sum, name_count, key, %{window: w}) do
    s = read(name_sum, key, %{window: w}) |> IO.inspect()
    c = read(name_count, key, %{window: w}) |> IO.inspect()
    if D.compare(c, 0) == :eq, do: D.new(0), else: D.div(s, c)
  end

  # RATE (por segundo/minuto/hora/día)
  def read_rate(name, key, opts \\ %{}) do
    w = Map.get(opts, :window, "24h")
    per = normalize_per(Map.get(opts, :per, :second))

    # Decimal
    s = read(name, key, %{window: w})
    # entero (segundos)
    secs = window_from_now(w)
    # 1/60/3600/86400
    base = per_to_base(per)

    if secs <= 0 do
      D.new(0)
    else
      # rate_per_unit = sum * base / secs  (todo en Decimal, sin floats)
      s
      |> D.mult(D.new(base))
      |> D.div(D.new(secs))
    end
  end

  # MAX / MIN (en la ventana)
  def read_max(name, key, %{window: w}), do: read_extreme(name, key, w, :max)
  def read_min(name, key, %{window: w}), do: read_extreme(name, key, w, :min)

  defp read_extreme(name, key_map, window, which) when which in [:max, :min] do
    acc = Repo.get_by!(Accumulator, name: name, status: :active)
    from_ts = window_from_now(window)

    {:ok, key_json} = normalize_key(key_map, acc.dimensions)
    key_hash = :crypto.hash(:sha256, Jason.encode!(key_json))

    q =
      from(b in Bucket,
        where:
          b.accumulator_id == ^acc.id and
            b.bucket_start >= ^from_ts and
            b.key_hash == ^key_hash
      )

    val =
      case which do
        :max -> Repo.aggregate(q, :max, :value_num)
        :min -> Repo.aggregate(q, :min, :value_num)
      end

    val || D.new(0)
  end

  # Time since last (segundos)
  def read_time_since_last(name, key_map) do
    acc = Repo.get_by!(Accumulator, name: name, status: :active)
    {:ok, key_json} = normalize_key(key_map, acc.dimensions)
    key_hash = :crypto.hash(:sha256, Jason.encode!(key_json))
    IO.puts("Ejecutando query")
    IO.inspect(acc)
    IO.inspect(key_json)

    case Repo.one(
           from(l in LastSeen,
             where: l.accumulator_id == ^acc.id and l.key_hash == ^key_hash,
             select: l.last_at
           )
         ) do
      nil ->
        :infinite

      %NaiveDateTime{} = last ->
        # last sin zona → conviértelo a UTC y calcula diferencia
        DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(last, "Etc/UTC"), :second)

      %DateTime{} = last ->
        # ya viene con zona (TIMESTAMPTZ); normaliza a UTC por claridad
        {:ok, last_utc} =
          if last.time_zone == "Etc/UTC" do
            {:ok, last}
          else
            DateTime.shift_zone(last, "Etc/UTC")
          end

        DateTime.diff(DateTime.utc_now(), last_utc, :second)
    end
  end
end
