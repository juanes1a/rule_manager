defmodule MsEvaluateRules.Infrastructure.Adapters.Repository.AuditLogData do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "audit_logs" do
    field :actor, :string
    field :entity_type, :string
    field :entity_id, :binary_id
    field :action, :string
    field :before, :map
    field :after, :map
    field :inserted_at, :utc_datetime
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:actor, :entity_type, :entity_id, :action, :before, :after, :inserted_at])
    |> validate_required([:actor, :entity_type, :entity_id, :action])
  end
end
