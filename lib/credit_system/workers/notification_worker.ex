defmodule CreditSystem.Workers.NotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => type, "application_id" => app_id} = args}) do
    Logger.info("[Notification] Processing #{type} notification for application #{app_id}")

    case type do
      "status_change" ->
        Logger.info(
          "[Notification] Application #{app_id} status changed to #{args["new_status"]}"
        )

      "review_required" ->
        Logger.info("[Notification] Application #{app_id} requires manual review")

      "application_created" ->
        Logger.info(
          "[Notification] New application #{app_id} created for country #{args["country"]}"
        )

      _ ->
        Logger.warning("[Notification] Unknown notification type: #{type}")
    end

    :ok
  end
end
