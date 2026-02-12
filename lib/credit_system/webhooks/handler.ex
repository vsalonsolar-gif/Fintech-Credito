defmodule CreditSystem.Webhooks.Handler do
  @moduledoc "Handles incoming webhooks from external banking providers"

  require Logger
  alias CreditSystem.Repo
  alias CreditSystem.Applications.CreditApplication
  alias CreditSystem.Webhooks.WebhookEvent
  alias CreditSystem.Cache

  def process_banking_webhook(params) do
    Logger.info(
      "[WebhookHandler] Processing incoming banking webhook: #{inspect(Map.keys(params))}"
    )

    with {:ok, app_id} <- extract_application_id(params),
         {:ok, application} <- get_application(app_id) do
      # Record incoming webhook
      %WebhookEvent{}
      |> WebhookEvent.changeset(%{
        application_id: app_id,
        event_type: "banking_update",
        direction: "incoming",
        payload: params,
        status: "received"
      })
      |> Repo.insert()

      # Process the update
      case params["event_type"] || params["type"] do
        "status_update" ->
          handle_status_update(application, params)

        "document_verified" ->
          handle_document_verified(application, params)

        "risk_assessment" ->
          handle_risk_assessment(application, params)

        _ ->
          Logger.warning("[WebhookHandler] Unknown webhook event type")
          {:ok, :acknowledged}
      end
    end
  end

  defp extract_application_id(%{"application_id" => id}) when is_binary(id), do: {:ok, id}
  defp extract_application_id(_), do: {:error, :missing_application_id}

  defp get_application(id) do
    case Repo.get(CreditApplication, id) do
      nil -> {:error, :application_not_found}
      app -> {:ok, app}
    end
  end

  defp handle_status_update(application, %{"new_status" => new_status}) do
    alias CreditSystem.Applications.StateMachine

    case StateMachine.transition(application, new_status) do
      {:ok, _} ->
        application
        |> Ecto.Changeset.change(%{status: new_status})
        |> Repo.update()

        Cache.invalidate_application(application.id)

        Phoenix.PubSub.broadcast(
          CreditSystem.PubSub,
          "applications",
          {:application_updated, application.id}
        )

        {:ok, :status_updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_status_update(_, _), do: {:error, :missing_new_status}

  defp handle_document_verified(application, params) do
    metadata =
      Map.merge(application.metadata || %{}, %{
        "document_verified" => true,
        "verification_source" => params["source"] || "banking_provider",
        "verified_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    application
    |> Ecto.Changeset.change(%{metadata: metadata})
    |> Repo.update()

    Cache.invalidate_application(application.id)
    {:ok, :document_verified}
  end

  defp handle_risk_assessment(application, params) do
    score = params["score"] || params["risk_score"]

    if score do
      application
      |> Ecto.Changeset.change(%{risk_score: score})
      |> Repo.update()

      Cache.invalidate_application(application.id)
      {:ok, :risk_assessed}
    else
      {:error, :missing_score}
    end
  end
end
