defmodule MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepositoryTest do
  use ExUnit.Case, async: false

  import Mock

  alias MsEvaluateRules.Infrastructure.Adapters.Dynamo.BucketQueryRepository, as: BQR
  @key <<0xAA, 0xBB, 0xCC>>

  defp defn() do
    # Minimal defn required by BQR: uses .id and optionally .bucket_gran via BucketUtil
    %{id: Ecto.UUID.generate(), bucket_gran: "hour"}
  end

  defp ref_h(window \\ "1h", gran \\ "hour") do
    %{"window" => window, "gran" => gran}
  end

  test "sum_window returns 0.0 when no items returned" do
    with_mock ExAws, request!: fn _op -> %{"Items" => []} end do
      assert BQR.sum_window(defn(), @key, ref_h()) == 0.0
    end
  end

  test "sum_window paginates and sums numeric values" do
    with_mock ExAws, request!: fn _op ->
      calls = Process.get(:calls) || 0
      Process.put(:calls, calls + 1)

      case calls do
        0 ->
          %{
            "Items" => [
              %{"value_num" => %{"N" => "1.5"}},
              %{"value_num" => %{"N" => "2"}}
            ],
            "LastEvaluatedKey" => %{"pk" => "p", "sk" => "ts:page1"}
          }

        1 ->
          %{"Items" => [%{"value_num" => %{"N" => "3"}}]}
      end
    end do
      total = BQR.sum_window(defn(), @key, ref_h())
      assert_in_delta total, 6.5, 1.0e-9
      assert Process.get(:calls) == 2
    end
  end

  test "sum_window respects max_pages limit" do
    with_mock ExAws, request!: fn _op ->
      calls = Process.get(:calls) || 0
      Process.put(:calls, calls + 1)

      %{
        "Items" => [
          %{"value_num" => %{"N" => "1"}},
          %{"value_num" => %{"N" => "2"}}
        ],
        "LastEvaluatedKey" => %{"pk" => "p", "sk" => "ts:next"}
      }
    end do
      total = BQR.sum_window(defn(), @key, ref_h(), max_pages: 1)
      assert total == 3.0
      assert Process.get(:calls) == 1
    end
  end

  test "extreme_window :max over pages" do
    with_mock ExAws, request!: fn _op ->
      calls = Process.get(:calls) || 0
      Process.put(:calls, calls + 1)

      case calls do
        0 ->
          %{
            "Items" => [
              %{"value_num" => %{"N" => "10.0"}},
              %{"value_num" => %{"N" => "3.5"}}
            ],
            "LastEvaluatedKey" => %{"pk" => "p", "sk" => "ts:page1"}
          }

        1 ->
          %{"Items" => [%{"value_num" => %{"N" => "5"}}]}
      end
    end do
      maxv = BQR.extreme_window(defn(), @key, ref_h(), :max)
      assert maxv == 10.0
      assert Process.get(:calls) == 2
    end
  end

  test "extreme_window :min over pages" do
    with_mock ExAws, request!: fn _op ->
      calls = Process.get(:calls) || 0
      Process.put(:calls, calls + 1)

      case calls do
        0 ->
          %{
            "Items" => [
              %{"value_num" => %{"N" => "10"}},
              %{"value_num" => %{"N" => "3.5"}}
            ],
            "LastEvaluatedKey" => %{"pk" => "p", "sk" => "ts:page1"}
          }

        1 ->
          %{"Items" => [%{"value_num" => %{"N" => "5.1"}}]}
      end
    end do
      minv = BQR.extreme_window(defn(), @key, ref_h(), :min)
      assert_in_delta minv, 3.5, 1.0e-9
      assert Process.get(:calls) == 2
    end
  end

  test "time_since_last returns 0 on future timestamp" do
    future = DateTime.to_unix(DateTime.utc_now()) + 10

    with_mock ExAws, request!: fn _op ->
      %{"Item" => %{"last_at" => %{"N" => Integer.to_string(future)}}}
    end do
      assert BQR.time_since_last(defn().id, @key) == 0
    end
  end

  test "time_since_last returns :infinite when no item" do
    with_mock ExAws, request!: fn _op -> %{} end do
      assert BQR.time_since_last(defn().id, @key) == :infinite
    end
  end

  test "sk_last returns the correct sort key" do
    assert BQR.sk_last() == "last"
  end
end
