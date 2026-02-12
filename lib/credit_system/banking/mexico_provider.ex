defmodule CreditSystem.Banking.MexicoProvider do
  @behaviour CreditSystem.Banking.Provider
  require Logger

  @impl true
  def get_client_info(curp) do
    # Simulated banking provider response for Mexico
    Logger.info("[MexicoBankingProvider] Fetching client info for CURP: #{mask_document(curp)}")

    # Simulate API latency
    Process.sleep(Enum.random(100..500))

    {:ok,
     %{
       "credit_score" => Enum.random(300..850),
       "existing_loans" => Enum.random(0..5),
       "bank_name" => Enum.random(["BBVA México", "Banorte", "Santander", "Citibanamex", "HSBC"]),
       "account_status" => Enum.random(["active", "inactive"]),
       "monthly_debt_payments" => Enum.random(1000..15000) |> to_string(),
       "credit_history_years" => Enum.random(0..20),
       "fetched_at" => DateTime.utc_now() |> DateTime.to_iso8601()
     }}
  end

  defp mask_document(doc) when byte_size(doc) > 4 do
    "****" <> String.slice(doc, -4..-1//1)
  end

  defp mask_document(_doc), do: "****"
end
