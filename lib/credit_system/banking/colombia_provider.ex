defmodule CreditSystem.Banking.ColombiaProvider do
  @behaviour CreditSystem.Banking.Provider
  require Logger

  @impl true
  def get_client_info(cc) do
    # Simulated banking provider response for Colombia
    Logger.info("[ColombiaBankingProvider] Fetching client info for CC: #{mask_document(cc)}")

    # Simulate API latency
    Process.sleep(Enum.random(100..500))

    {:ok,
     %{
       "total_debt" => Enum.random(0..50_000_000) |> to_string(),
       "credit_history_months" => Enum.random(0..240),
       "risk_level" => Enum.random(["low", "medium", "high"]),
       "bank_name" =>
         Enum.random(["Bancolombia", "Davivienda", "BBVA Colombia", "Banco de Bogotá"]),
       "reported_income" => Enum.random(1_500_000..15_000_000) |> to_string(),
       "active_products" => Enum.random(0..8),
       "fetched_at" => DateTime.utc_now() |> DateTime.to_iso8601()
     }}
  end

  defp mask_document(doc) when byte_size(doc) > 4 do
    "****" <> String.slice(doc, -4..-1//1)
  end

  defp mask_document(_doc), do: "****"
end
