defmodule CreditSystem.Workers.AuditWorker do
  use Oban.Worker, queue: :audit, max_attempts: 5

  require Logger
  alias CreditSystem.Repo
  alias CreditSystem.Applications.AuditLog

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info(
      "[Audit] Recording action: #{args["action"]} for application #{args["application_id"]}"
    )

    result =
      %AuditLog{}
      |> AuditLog.changeset(%{
        application_id: args["application_id"],
        action: args["action"],
        old_state: args["old_state"],
        new_state: args["new_state"],
        details: args["details"] || %{},
        user_id: args["user_id"]
      })
      |> Repo.insert()

    case result do
      {:ok, _} ->
        Logger.info("[Audit] Successfully recorded audit log")
        :ok

      {:error, changeset} ->
        Logger.error("[Audit] Failed to record: #{inspect(changeset.errors)}")
        {:error, :insert_failed}
    end
  end
end
