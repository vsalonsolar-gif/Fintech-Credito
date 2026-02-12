defmodule CreditSystem.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :application_id,
          references(:credit_applications, type: :binary_id, on_delete: :nothing), null: false

      add :action, :string, null: false
      add :old_state, :string
      add :new_state, :string
      add :details, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:audit_logs, [:application_id])
    create index(:audit_logs, [:inserted_at])
  end
end
