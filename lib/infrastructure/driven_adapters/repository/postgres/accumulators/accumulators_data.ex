defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.Accumulator do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :kind,
             :dimensions,
             :value_field,
             :bucket_gran,
             :retention_days,
             :status
           ]}

  schema "accumulators" do
    field(:name, :string)
    field(:description, :string)
    field(:kind, Ecto.Enum, values: [:count, :sum, :max, :min, :uniq_count])
    field(:dimensions, {:array, :string}, default: [])
    field(:value_field, :string)
    field(:bucket_gran, Ecto.Enum, values: [:minute, :hour, :day])
    field(:retention_days, :integer, default: 90)
    field(:status, Ecto.Enum, values: [:active, :inactive], default: :active)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(acc, attrs) do
    acc
    |> cast(attrs, [
      :name,
      :description,
      :kind,
      :dimensions,
      :value_field,
      :bucket_gran,
      :retention_days,
      :status
    ])
    |> validate_required([:name, :kind, :bucket_gran])
    |> unique_constraint(:name)
  end
end
