defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.DeploymentData do
  use Ecto.Schema
  import Ecto.Changeset

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.SignatureData
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.RuleSetData

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "deployments" do
    field :version, :integer
    field :activated_by, :string
    field :activated_at, :utc_datetime
    field :notes, :string

    belongs_to :signature, SignatureData, type: :binary_id
    belongs_to :ruleset, RuleSetData, type: :binary_id

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def changeset(dep, attrs) do
    dep
    |> cast(attrs, [:signature_id, :ruleset_id, :version, :activated_by, :activated_at, :notes])
    |> validate_required([:signature_id, :ruleset_id, :version, :activated_by])
  end
end
