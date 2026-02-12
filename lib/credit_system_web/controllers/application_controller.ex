defmodule CreditSystemWeb.ApplicationController do
  use CreditSystemWeb, :controller

  alias CreditSystem.Applications

  action_fallback CreditSystemWeb.FallbackController

  def index(conn, params) do
    applications = Applications.list_applications(params)

    conn
    |> json(%{
      data: Enum.map(applications, &serialize_application/1)
    })
  end

  def show(conn, %{"id" => id}) do
    with {:ok, application} <- Applications.get_application(id) do
      conn
      |> json(%{data: serialize_application_detail(application)})
    end
  end

  def create(conn, %{"application" => attrs}) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(attrs, "user_id", user.id)

    with {:ok, application} <- Applications.create_application(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize_application(application)})
    end
  end

  def create(conn, attrs) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(attrs, "user_id", user.id)

    with {:ok, application} <- Applications.create_application(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize_application(application)})
    end
  end

  def update_status(conn, %{"id" => id, "status" => new_status}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, application} <- Applications.get_application(id),
         {:ok, updated} <- Applications.update_status(application, new_status, user.id) do
      conn
      |> json(%{data: serialize_application(updated)})
    end
  end

  defp serialize_application(app) do
    %{
      id: app.id,
      country: app.country,
      full_name: app.full_name,
      document_type: app.document_type,
      identity_document: mask_document(app.identity_document),
      requested_amount: app.requested_amount,
      monthly_income: app.monthly_income,
      application_date: app.application_date,
      status: app.status,
      risk_score: app.risk_score,
      inserted_at: app.inserted_at
    }
  end

  defp serialize_application_detail(app) do
    base = serialize_application(app)

    audit_logs =
      if Ecto.assoc_loaded?(app.audit_logs) do
        Enum.map(app.audit_logs, fn log ->
          %{
            action: log.action,
            old_state: log.old_state,
            new_state: log.new_state,
            details: log.details,
            inserted_at: log.inserted_at
          }
        end)
      else
        []
      end

    Map.put(base, :audit_logs, audit_logs)
  end

  defp mask_document(doc) when is_binary(doc) and byte_size(doc) > 4 do
    String.duplicate("*", byte_size(doc) - 4) <> String.slice(doc, -4..-1//1)
  end

  defp mask_document(doc), do: doc
end
