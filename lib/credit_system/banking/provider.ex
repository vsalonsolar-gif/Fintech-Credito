defmodule CreditSystem.Banking.Provider do
  @callback get_client_info(String.t()) :: {:ok, map()} | {:error, term()}

  def get_provider("MX"), do: {:ok, CreditSystem.Banking.MexicoProvider}
  def get_provider("CO"), do: {:ok, CreditSystem.Banking.ColombiaProvider}
  def get_provider(_), do: {:error, :unsupported_country}

  def fetch_client_info(country, document) do
    with {:ok, provider} <- get_provider(country) do
      provider.get_client_info(document)
    end
  end
end
