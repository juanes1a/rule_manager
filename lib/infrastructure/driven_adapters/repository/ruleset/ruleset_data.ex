defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.RuleSetData do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @status ~w(draft published archived)a
  @foreign_key_type :binary_id

  schema "rulesets" do
    field(:version, :integer)
    field(:status, Ecto.Enum, values: @status, default: :draft)
    field(:valid_from, :utc_datetime)
    field(:valid_to, :utc_datetime)

    belongs_to(:signature,  MsEvaluateRules.Infrastructure.Adapters.Repository.SignatureData, foreign_key: :signature_id, type: :binary_id)
    has_many(:rules, MsEvaluateRules.Infrastructure.Adapters.Repository.RuleData, foreign_key: :ruleset_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(rs, attrs) do
    rs
    |> cast(attrs, [:signature_id, :version, :status, :valid_from, :valid_to])
    |> validate_required([:signature_id, :version, :status])
    |> unique_constraint([:signature_id, :version])
  end
end
