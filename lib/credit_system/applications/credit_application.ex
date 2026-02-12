defmodule CreditSystem.Applications.CreditApplication do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "credit_applications" do
    field :country, :string
    field :full_name, :string
    field :identity_document, :string
    field :document_type, :string
    field :requested_amount, :decimal
    field :monthly_income, :decimal
    field :application_date, :date
    field :status, :string, default: "pending"
    field :banking_info, :map, default: %{}
    field :risk_score, :integer
    field :metadata, :map, default: %{}
    field :lock_version, :integer, default: 1

    belongs_to :user, CreditSystem.Auth.User

    has_many :audit_logs, CreditSystem.Applications.AuditLog, foreign_key: :application_id
    has_many :webhook_events, CreditSystem.Webhooks.WebhookEvent, foreign_key: :application_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :country,
    :full_name,
    :identity_document,
    :document_type,
    :requested_amount,
    :monthly_income,
    :application_date
  ]
  @optional_fields [:status, :banking_info, :risk_score, :metadata, :user_id, :lock_version]

  def changeset(application, attrs) do
    application
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:country, ["MX", "CO"])
    |> validate_number(:requested_amount, greater_than: 0)
    |> validate_number(:monthly_income, greater_than: 0)
    |> optimistic_lock(:lock_version)
  end

  def status_changeset(application, new_status) do
    application
    |> change(status: new_status)
    |> optimistic_lock(:lock_version)
  end
end
