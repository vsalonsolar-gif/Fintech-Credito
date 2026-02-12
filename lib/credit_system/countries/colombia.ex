defmodule CreditSystem.Countries.Colombia do
  @behaviour CreditSystem.Countries.Country

  @cc_regex ~r/^\d{6,10}$/

  @impl true
  def country_code, do: "CO"

  @impl true
  def document_type, do: "CC"

  @impl true
  def max_amount, do: Decimal.new("200000000")

  @impl true
  def validate_document(cc) do
    cc = String.trim(cc)

    if Regex.match?(@cc_regex, cc) do
      {:ok, cc}
    else
      {:error, "Formato de Cedula de Ciudadania invalido. Debe tener de 6 a 10 digitos"}
    end
  end

  @impl true
  def validate_application(attrs) do
    errors = []

    requested_amount = to_decimal(attrs["requested_amount"] || attrs[:requested_amount])
    monthly_income = to_decimal(attrs["monthly_income"] || attrs[:monthly_income])
    banking_info = attrs["banking_info"] || attrs[:banking_info] || %{}
    total_debt = to_decimal(banking_info["total_debt"] || banking_info[:total_debt])

    # Rule 1: Max amount 200,000,000 COP
    errors =
      if requested_amount && Decimal.compare(requested_amount, max_amount()) == :gt do
        ["El monto solicitado excede el maximo de 200,000,000 COP" | errors]
      else
        errors
      end

    # Rule 2: Debt-to-income ratio must be < 0.4
    errors =
      if total_debt && monthly_income && Decimal.compare(monthly_income, Decimal.new(0)) == :gt do
        ratio = Decimal.div(total_debt, monthly_income)

        if Decimal.compare(ratio, Decimal.new("0.4")) != :lt do
          ["La relacion deuda-ingreso (#{ratio}) excede el maximo de 0.4" | errors]
        else
          errors
        end
      else
        errors
      end

    # Rule 3: Amount > 100,000,000 requires additional review
    metadata =
      if requested_amount && Decimal.compare(requested_amount, Decimal.new("100000000")) == :gt do
        %{requires_additional_review: true}
      else
        %{}
      end

    case errors do
      [] -> {:ok, metadata}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_number(n), do: Decimal.new(to_string(n))
  defp to_decimal(s) when is_binary(s), do: Decimal.new(s)
  defp to_decimal(_), do: nil
end
