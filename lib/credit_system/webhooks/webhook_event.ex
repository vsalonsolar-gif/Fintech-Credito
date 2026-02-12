defmodule CreditSystem.Webhooks.WebhookEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_events" do
    field :event_type, :string
    field :direction, :string, default: "outgoing"
    field :payload, :map, default: %{}
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :response, :map

    belongs_to :application, CreditSystem.Applications.CreditApplication,
      foreign_key: :application_id

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook_event, attrs) do
    webhook_event
    |> cast(attrs, [
      :application_id,
      :event_type,
      :direction,
      :payload,
      :status,
      :attempts,
      :response
    ])
    |> validate_required([:event_type, :direction])
    |> validate_inclusion(:direction, ["incoming", "outgoing"])
    |> validate_inclusion(:status, ["pending", "sent", "failed", "received"])
  end
end
