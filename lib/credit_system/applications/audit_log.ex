defmodule CreditSystem.Applications.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field :action, :string
    field :old_state, :string
    field :new_state, :string
    field :details, :map, default: %{}

    belongs_to :application, CreditSystem.Applications.CreditApplication,
      foreign_key: :application_id

    belongs_to :user, CreditSystem.Auth.User

    field :inserted_at, :utc_datetime
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:application_id, :action, :old_state, :new_state, :details, :user_id])
    |> validate_required([:application_id, :action])
  end
end
