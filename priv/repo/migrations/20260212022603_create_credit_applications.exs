defmodule CreditSystem.Repo.Migrations.CreateCreditApplications do
  use Ecto.Migration

  def change do
    create table(:credit_applications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country, :string, null: false
      add :full_name, :string, null: false
      add :identity_document, :string, null: false
      add :document_type, :string, null: false
      add :requested_amount, :decimal, null: false, precision: 18, scale: 2
      add :monthly_income, :decimal, null: false, precision: 18, scale: 2
      add :application_date, :date, null: false
      add :status, :string, null: false, default: "pending"
      add :banking_info, :map, default: %{}
      add :risk_score, :integer
      add :metadata, :map, default: %{}
      add :lock_version, :integer, default: 1
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:credit_applications, [:country])
    create index(:credit_applications, [:status])
    create index(:credit_applications, [:country, :status])
    create index(:credit_applications, [:application_date])
    create index(:credit_applications, [:identity_document])
    create index(:credit_applications, [:user_id])

    # Partial index for active applications (not completed/rejected)
    execute(
      "CREATE INDEX idx_active_applications ON credit_applications (status) WHERE status NOT IN ('rejected', 'disbursed')",
      "DROP INDEX idx_active_applications"
    )
  end
end
