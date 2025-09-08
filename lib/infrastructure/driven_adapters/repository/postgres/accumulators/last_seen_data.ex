defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.Accumulators.LastSeen do
  use Ecto.Schema
  @primary_key false
  schema "acc_last_seen" do
    field :accumulator_id, :binary_id
    field :key_json, :map
    field :key_hash, :binary
    field :last_at, :utc_datetime
    field :count, :integer
    timestamps(inserted_at: false, updated_at: :updated_at, type: :utc_datetime_usec)
  end
end
