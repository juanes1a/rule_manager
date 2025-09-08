defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.Bucket do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false

  schema "acc_buckets" do
    field(:accumulator_id, :binary_id)
    field(:bucket_start, :utc_datetime)
    field(:key_json, :map)
    field(:key_hash, :binary)
    field(:value_num, :decimal)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(b, attrs) do
    b
    |> cast(attrs, [:accumulator_id, :bucket_start, :key_json, :key_hash, :value_num])
    |> validate_required([:accumulator_id, :bucket_start, :key_json, :key_hash])
  end
end
