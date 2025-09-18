defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.ApplicationData do
  use Ecto.Schema
  import Ecto.Changeset

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.SignatureData

  @primary_key {:id, :binary_id, autogenerate: true}
  @status ~w(active inactive)a
  @foreign_key_type :binary_id

  schema "applications" do
    field(:name, :string)
    field(:status, Ecto.Enum, values: @status, default: :active)

    has_many(:signatures, SignatureData, foreign_key: :app_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :status])
    |> validate_required([:name])
    |> validate_inclusion(:status, @status)
    |> unique_constraint(:name)
  end
end
