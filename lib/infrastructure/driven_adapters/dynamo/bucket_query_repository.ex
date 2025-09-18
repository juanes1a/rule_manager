defmodule MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository do
  alias ExAws.Dynamo

  require MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtil
  import MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketUtil

  @table "acc_buckets"

  defp query_once!(table, opts) do
    ExAws.Dynamo.query(table, opts) |> ExAws.request!()
  end

  # === Read: suma en ventana (para sum/count) ===
  def sum_window(accumulator, key_hash, ref, opts \\ []) do
    {from_sk, to_sk} = bounds(ref, accumulator)
    # defensa: si el rango está invertido, retorna 0
    if from_sk > to_sk do
      0.0
    else
      base_opts = [
        key_condition_expression: "pk = :pk AND sk BETWEEN :from AND :to",
        expression_attribute_values: [pk: pk(accumulator.id, key_hash), from: from_sk, to: to_sk],
        select: "SPECIFIC_ATTRIBUTES",
        projection_expression: "#v",
        expression_attribute_names: %{"#v" => "value_num"}
        # opcional: limit: 500  # para paginar más rápido/local
      ]

      reducer = fn acc, items ->
        acc +
          (items
           |> Enum.map(fn %{"value_num" => %{"N" => n}} -> to_float!(n) end)
           |> Enum.sum())
      end

      paginate_reduce(@table, base_opts, 0.0, reducer, opts)
    end
  end

  # === Read: max/min en ventana ===
  def extreme_window(accumulator, key_hash, ref, which, opts \\ []) when which in [:max, :min] do
    {from_sk, to_sk} = bounds(ref, accumulator)
    if from_sk > to_sk do
      0.0
    else
      base_opts = [
        key_condition_expression: "pk = :pk AND sk BETWEEN :from AND :to",
        expression_attribute_values: [pk: pk(accumulator.id, key_hash), from: from_sk, to: to_sk],
        select: "SPECIFIC_ATTRIBUTES",
        projection_expression: "#v",
        expression_attribute_names: %{"#v" => "value_num"}
      ]

      reducer =
        case which do
          :max ->
            fn
              nil, items ->
                case items do
                  [] -> nil
                  _ -> items |> Enum.map(&to_float!(&1["value_num"]["N"])) |> Enum.max()
                end

              acc, items ->
                case items do
                  [] -> acc
                  _ -> max(acc, items |> Enum.map(&to_float!(&1["value_num"]["N"])) |> Enum.max())
                end
            end

          :min ->
            fn
              nil, items ->
                case items do
                  [] -> nil
                  _ -> items |> Enum.map(&to_float!(&1["value_num"]["N"])) |> Enum.min()
                end

              acc, items ->
                case items do
                  [] -> acc
                  _ -> min(acc, items |> Enum.map(&to_float!(&1["value_num"]["N"])) |> Enum.min())
                end
            end
        end

      res = paginate_reduce(@table, base_opts, nil, reducer, opts)
      res || 0.0
    end
  end

  # === Read: time_since_last (segundos) ===
  def time_since_last(acc_id, key_hash) do
    key = %{"pk" => pk(acc_id, key_hash), "sk" => sk_last()}

    req =
      Dynamo.get_item(@table, key,
        projection_expression: "#l",
        expression_attribute_names: %{"#l" => "last_at"}
      )

    case ExAws.request!(req) do
      %{"Item" => %{"last_at" => %{"N" => n}}} ->
        last = String.to_integer(n)
        diff = DateTime.to_unix(DateTime.utc_now()) - last
        if diff < 0, do: 0, else: diff

      _ ->
        :infinite
    end
  end

  def sk_last, do: "last"

  defp to_float!(n) when is_binary(n) do
    case Float.parse(n) do
      {f, ""} -> f
      _ -> String.to_integer(n) * 1.0
    end
  end

  defp paginate_reduce(table, base_opts, acc0, reducer, opts \\ []) do
    # fusible
    max_pages = Keyword.get(opts, :max_pages, 2_000)
    seen_hash = MapSet.new()

    do_page(table, base_opts, acc0, reducer, nil, 0, max_pages, seen_hash)
  end

  defp do_page(_table, _base_opts, acc, _reducer, _lek, page, max_pages, _seen)
       when page >= max_pages do
    acc
  end

  defp do_page(table, base_opts, acc, reducer, lek, page, max_pages, seen) do
    opts = if lek, do: Keyword.put(base_opts, :exclusive_start_key, lek), else: base_opts
    resp = query_once!(table, opts)

    items = resp["Items"] || []
    new_acc = reducer.(acc, items)

    case resp["LastEvaluatedKey"] do
      nil ->
        new_acc

      next when is_map(next) ->
        # Evita bucle si Dynamo (o el cliente) devuelve el mismo LEK
        key_sig = :erlang.phash2(next)

        if MapSet.member?(seen, key_sig) do
          new_acc
        else
          do_page(
            table,
            base_opts,
            new_acc,
            reducer,
            next,
            page + 1,
            max_pages,
            MapSet.put(seen, key_sig)
          )
        end
    end
  end
end
