defmodule CreditSystem.Applications do
  @moduledoc "Context for managing credit applications"

  import Ecto.Query
  require Logger

  alias CreditSystem.Repo
  alias CreditSystem.Cache
  alias CreditSystem.Applications.{CreditApplication, StateMachine, AuditLog}
  alias CreditSystem.Countries.Country
  alias CreditSystem.Workers.{RiskEvaluationWorker, AuditWorker, NotificationWorker}

  def list_applications(filters \\ %{}) do
    cache_key = :erlang.phash2(filters)

    case Cache.get_list(cache_key) do
      {:ok, nil} ->
        result = build_query(filters) |> Repo.all()
        Cache.put_list(cache_key, result)
        result

      {:ok, cached} ->
        cached
    end
  end

  def get_application(id) do
    case Cache.get_application(id) do
      {:ok, nil} ->
        case Repo.get(CreditApplication, id) do
          nil ->
            {:error, :not_found}

          application ->
            application = Repo.preload(application, [:audit_logs, :webhook_events])
            Cache.put_application(id, application)
            {:ok, application}
        end

      {:ok, cached} ->
        {:ok, cached}
    end
  end

  def create_application(attrs) do
    country = attrs["country"] || attrs[:country]

    with {:ok, country_module} <- Country.get_module(country),
         {:ok, document} <-
           country_module.validate_document(
             attrs["identity_document"] || attrs[:identity_document] || ""
           ) do
      attrs =
        attrs
        |> Map.put("document_type", country_module.document_type())
        |> Map.put("identity_document", document)
        |> Map.put("application_date", Date.utc_today())
        |> Map.put("status", "pending")

      result =
        %CreditApplication{}
        |> CreditApplication.changeset(attrs)
        |> Repo.insert()

      case result do
        {:ok, application} ->
          Cache.invalidate_lists()

          # Enqueue async processing
          %{application_id: application.id}
          |> RiskEvaluationWorker.new()
          |> Oban.insert()

          %{
            application_id: application.id,
            action: "application_created",
            new_state: "pending",
            details: %{country: country}
          }
          |> AuditWorker.new()
          |> Oban.insert()

          %{
            type: "application_created",
            application_id: application.id,
            country: country
          }
          |> NotificationWorker.new()
          |> Oban.insert()

          # Transition to validating
          update_status(application, "validating")

          Phoenix.PubSub.broadcast(
            CreditSystem.PubSub,
            "applications",
            {:application_created, application.id}
          )

          {:ok, application}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  def update_status(application, new_status, user_id \\ nil) do
    with {:ok, _} <- StateMachine.transition(application, new_status) do
      old_status = application.status

      result =
        application
        |> CreditApplication.status_changeset(new_status)
        |> Repo.update()

      case result do
        {:ok, updated} ->
          Cache.invalidate_application(application.id)

          %{
            application_id: application.id,
            action: "status_changed",
            old_state: old_status,
            new_state: new_status,
            user_id: user_id
          }
          |> AuditWorker.new()
          |> Oban.insert()

          Phoenix.PubSub.broadcast(
            CreditSystem.PubSub,
            "applications",
            {:application_updated, application.id}
          )

          Phoenix.PubSub.broadcast(
            CreditSystem.PubSub,
            "application:#{application.id}",
            {:status_changed, new_status}
          )

          {:ok, updated}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  def get_audit_logs(application_id) do
    AuditLog
    |> where([a], a.application_id == ^application_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @supported_countries ["MX", "CO"]

  def supported_countries, do: @supported_countries

  defp build_query(filters) do
    CreditApplication
    |> maybe_filter_country(filters)
    |> maybe_filter_status(filters)
    |> maybe_filter_date_range(filters)
    |> order_by([a], desc: a.inserted_at)
    |> limit(100)
  end

  defp maybe_filter_country(query, %{"country" => country}) when country != "" do
    where(query, [a], a.country == ^country)
  end

  defp maybe_filter_country(query, %{country: country}) when country != "" do
    where(query, [a], a.country == ^country)
  end

  defp maybe_filter_country(query, _) do
    where(query, [a], a.country in ^@supported_countries)
  end

  defp maybe_filter_status(query, %{"status" => status}) when status != "" do
    where(query, [a], a.status == ^status)
  end

  defp maybe_filter_status(query, %{status: status}) when status != "" do
    where(query, [a], a.status == ^status)
  end

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_date_range(query, %{"from" => from, "to" => to})
       when from != "" and to != "" do
    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      where(query, [a], a.application_date >= ^from_date and a.application_date <= ^to_date)
    else
      _ -> query
    end
  end

  defp maybe_filter_date_range(query, _), do: query
end
