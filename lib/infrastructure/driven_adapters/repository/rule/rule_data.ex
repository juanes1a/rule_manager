defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.RuleData do
  use Ecto.Schema
  import Ecto.Changeset

  alias MsEvaluateRules.Infrastructure.Adapters.Repository.RuleSetData

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rules" do
    field(:name, :string)
    field(:priority, :integer)
    field(:enabled, :boolean, default: true)
    field(:condition, :map)
    field(:effects, {:array, :map}, default: [])
    field(:stop_on_match, :boolean, default: false)
    field(:valid_from, :utc_datetime)
    field(:valid_to, :utc_datetime)
    field(:tags, {:array, :string}, default: [])

    belongs_to(:ruleset, RuleSetData, foreign_key: :ruleset_id, type: :binary_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :ruleset_id,
      :name,
      :priority,
      :enabled,
      :condition,
      :effects,
      :stop_on_match,
      :valid_from,
      :valid_to,
      :tags
    ])
    |> validate_required([:ruleset_id, :name, :priority, :condition, :effects])
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> unique_constraint([:ruleset_id, :name])
  end
end
