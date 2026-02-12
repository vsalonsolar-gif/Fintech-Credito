defmodule CreditSystemWeb.WebhookController do
  use CreditSystemWeb, :controller

  alias CreditSystem.Webhooks.Handler

  def banking_update(conn, params) do
    case Handler.process_banking_webhook(params) do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok", result: result})

      {:error, :missing_application_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing application_id"})

      {:error, :application_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Application not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end
end
