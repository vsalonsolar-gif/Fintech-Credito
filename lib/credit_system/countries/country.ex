defmodule CreditSystem.Countries.Country do
  @callback validate_document(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback validate_application(map()) :: {:ok, map()} | {:error, list()}
  @callback document_type() :: String.t()
  @callback country_code() :: String.t()
  @callback max_amount() :: Decimal.t()

  def get_module("MX"), do: {:ok, CreditSystem.Countries.Mexico}
  def get_module("CO"), do: {:ok, CreditSystem.Countries.Colombia}
  def get_module(_), do: {:error, :unsupported_country}
end
