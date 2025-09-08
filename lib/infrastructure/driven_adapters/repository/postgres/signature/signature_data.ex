defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.SignatureData do
  use Ecto.Schema
  import Ecto.Changeset

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.ApplicationData
  alias MsEvaluateRules.Infrastructure.Adapters.Repository.RuleSetData

  @primary_key {:id, :binary_id, autogenerate: true}
  @status ~w(active inactive)a
  @output_mode ~w(score boolean string)a
  @aggregation ~w(sum max first_match any_true)a
  @foreign_key_type :binary_id

  schema "signatures" do
    field(:name, :string)
    field(:output_mode, Ecto.Enum, values: @output_mode)
    field(:aggregation, Ecto.Enum, values: @aggregation)
    field(:mapping, :map)
    field(:field_defs, :map)
    field(:active_version, :integer)
    field(:status, Ecto.Enum, values: @status, default: :active)

    belongs_to(:application, ApplicationData, foreign_key: :app_id, type: :binary_id)
    has_many(:rulesets, RuleSetData, foreign_key: :signature_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(sig, attrs) do
    sig
    |> cast(attrs, [
      :app_id,
      :name,
      :output_mode,
      :aggregation,
      :mapping,
      :field_defs,
      :active_version,
      :status
    ])
    |> validate_required([:app_id, :name, :output_mode, :aggregation, :mapping, :field_defs])
    |> unique_constraint([:app_id, :name])
  end
end
