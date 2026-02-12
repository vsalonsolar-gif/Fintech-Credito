defmodule CreditSystem.Workers.RiskEvaluationWorker do
  use Oban.Worker, queue: :risk, max_attempts: 3

  require Logger
  alias CreditSystem.{Repo, Cache}
  alias CreditSystem.Applications.CreditApplication
  alias CreditSystem.Banking.Provider
  alias CreditSystem.Countries.Country

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"application_id" => application_id}}) do
    Logger.info("[RiskEvaluation] Starting evaluation for application #{application_id}")

    with {:ok, application} <- get_application(application_id),
         {:ok, banking_info} <-
           Provider.fetch_client_info(application.country, application.identity_document),
         {:ok, country_module} <- Country.get_module(application.country),
         validation_result <-
           country_module.validate_application(
             Map.merge(
               Map.from_struct(application),
               %{banking_info: banking_info}
             )
           ) do
      risk_score = calculate_risk_score(banking_info, application.country)

      {new_status, metadata} =
        case validation_result do
          {:ok, meta} ->
            status = if meta[:requires_additional_review], do: "under_review", else: "approved"
            {status, meta}

          {:error, reasons} ->
            {"rejected", %{rejection_reasons: reasons}}
        end

      application
      |> Ecto.Changeset.change(%{
        status: new_status,
        banking_info: sanitize_banking_info(banking_info),
        risk_score: risk_score,
        metadata: Map.merge(application.metadata || %{}, metadata)
      })
      |> Repo.update()

      Cache.invalidate_application(application_id)

      # Broadcast status change
      Phoenix.PubSub.broadcast(
        CreditSystem.PubSub,
        "applications",
        {:application_updated, application_id}
      )

      Phoenix.PubSub.broadcast(
        CreditSystem.PubSub,
        "application:#{application_id}",
        {:status_changed, new_status}
      )

      # Enqueue webhook notification
      %{application_id: application_id, event: "status_changed", new_status: new_status}
      |> CreditSystem.Workers.WebhookWorker.new()
      |> Oban.insert()

      # Enqueue audit log
      %{
        application_id: application_id,
        action: "risk_evaluation_completed",
        old_state: "validating",
        new_state: new_status,
        details: %{risk_score: risk_score}
      }
      |> CreditSystem.Workers.AuditWorker.new()
      |> Oban.insert()

      Logger.info(
        "[RiskEvaluation] Completed for #{application_id}: #{new_status} (score: #{risk_score})"
      )

      :ok
    else
      {:error, reason} ->
        Logger.error("[RiskEvaluation] Failed for #{application_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_application(id) do
    case Repo.get(CreditApplication, id) do
      nil -> {:error, :not_found}
      app -> {:ok, app}
    end
  end

  defp calculate_risk_score(banking_info, "MX") do
    credit_score = banking_info["credit_score"] || 500
    existing_loans = banking_info["existing_loans"] || 0
    base = div(credit_score, 10)
    penalty = existing_loans * 5
    max(0, min(100, base - penalty))
  end

  defp calculate_risk_score(banking_info, "CO") do
    risk_level = banking_info["risk_level"] || "medium"
    history = banking_info["credit_history_months"] || 0

    base =
      case risk_level do
        "low" -> 80
        "medium" -> 50
        "high" -> 20
        _ -> 50
      end

    bonus = min(20, div(history, 12))
    min(100, base + bonus)
  end

  defp calculate_risk_score(_, _), do: 50

  defp sanitize_banking_info(info) do
    # Remove sensitive fields before storing
    Map.drop(info, ["account_number", "routing_number", "ssn"])
  end
end
