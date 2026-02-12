defmodule CreditSystem.Countries.Mexico do
  @behaviour CreditSystem.Countries.Country

  @curp_regex ~r/^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$/

  @impl true
  def country_code, do: "MX"

  @impl true
  def document_type, do: "CURP"

  @impl true
  def max_amount, do: Decimal.new("500000")

  @impl true
  def validate_document(curp) do
    curp = String.trim(curp) |> String.upcase()

    if Regex.match?(@curp_regex, curp) do
      {:ok, curp}
    else
      {:error,
       "Formato de CURP invalido. Debe ser 18 caracteres: 4 letras + 6 digitos + letra de genero + 5 letras + alfanumerico + digito"}
    end
  end

  @impl true
  def validate_application(attrs) do
    errors = []

    requested_amount = to_decimal(attrs["requested_amount"] || attrs[:requested_amount])
    monthly_income = to_decimal(attrs["monthly_income"] || attrs[:monthly_income])

    # Rule 1: Max amount 500,000 MXN
    errors =
      if requested_amount && Decimal.compare(requested_amount, max_amount()) == :gt do
        ["El monto solicitado excede el maximo de 500,000 MXN" | errors]
      else
        errors
      end

    # Rule 2: Monthly income must be >= 3x the monthly payment (assuming 12 month term)
    errors =
      if requested_amount && monthly_income do
        monthly_payment = Decimal.div(requested_amount, Decimal.new(12))
        min_income = Decimal.mult(monthly_payment, Decimal.new(3))

        if Decimal.compare(monthly_income, min_income) == :lt do
          [
            "El ingreso mensual debe ser al menos 3 veces el pago mensual. Minimo requerido: #{min_income}"
            | errors
          ]
        else
          errors
        end
      else
        errors
      end

    # Rule 3: Amount > 250,000 requires additional review
    metadata =
      if requested_amount && Decimal.compare(requested_amount, Decimal.new("250000")) == :gt do
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
