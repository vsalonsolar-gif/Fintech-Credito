defmodule CreditSystem.Repo.Migrations.CreateWebhookEvents do
  use Ecto.Migration

  def change do
    create table(:webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :application_id, references(:credit_applications, type: :binary_id, on_delete: :nothing)
      add :event_type, :string, null: false
      add :direction, :string, null: false, default: "outgoing"
      add :payload, :map, default: %{}
      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :response, :map

      timestamps(type: :utc_datetime)
    end

    create index(:webhook_events, [:application_id])
    create index(:webhook_events, [:event_type])
    create index(:webhook_events, [:status])
  end
end
