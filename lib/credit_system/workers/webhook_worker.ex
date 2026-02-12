defmodule CreditSystem.Workers.WebhookWorker do
  use Oban.Worker, queue: :webhooks, max_attempts: 3

  require Logger
  alias CreditSystem.Repo
  alias CreditSystem.Webhooks.WebhookEvent

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"application_id" => app_id, "event" => event} = args}) do
    webhook_url = Application.get_env(:credit_system, :webhook_url)
    Logger.info("[Webhook] Sending #{event} for application #{app_id} to #{webhook_url}")

    payload = %{
      event: event,
      application_id: app_id,
      new_status: args["new_status"],
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Record the webhook event
    webhook_event =
      %WebhookEvent{}
      |> WebhookEvent.changeset(%{
        application_id: app_id,
        event_type: event,
        direction: "outgoing",
        payload: payload,
        status: "pending"
      })
      |> Repo.insert!()

    # Send the webhook (simulated - will fail gracefully if no receiver)
    result =
      try do
        request =
          Finch.build(
            :post,
            webhook_url,
            [{"content-type", "application/json"}],
            Jason.encode!(payload)
          )

        case Finch.request(request, CreditSystem.Finch, receive_timeout: 5000) do
          {:ok, %{status: status}} when status in 200..299 ->
            {:ok, %{status: status}}

          {:ok, %{status: status, body: body}} ->
            {:error, %{status: status, body: body}}

          {:error, reason} ->
            {:error, %{reason: inspect(reason)}}
        end
      rescue
        e -> {:error, %{reason: inspect(e)}}
      end

    case result do
      {:ok, response} ->
        webhook_event
        |> Ecto.Changeset.change(%{
          status: "sent",
          attempts: webhook_event.attempts + 1,
          response: response
        })
        |> Repo.update()

        Logger.info("[Webhook] Successfully sent #{event} for #{app_id}")
        :ok

      {:error, error_info} ->
        webhook_event
        |> Ecto.Changeset.change(%{
          status: "failed",
          attempts: webhook_event.attempts + 1,
          response: error_info
        })
        |> Repo.update()

        Logger.warning("[Webhook] Failed to send #{event} for #{app_id}: #{inspect(error_info)}")
        # Return ok so it doesn't retry forever - webhook failures are non-critical
        :ok
    end
  end
end
