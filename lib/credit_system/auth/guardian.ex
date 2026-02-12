defmodule CreditSystem.Auth.Guardian do
  use Guardian, otp_app: :credit_system

  alias CreditSystem.Auth

  def subject_for_token(%{id: id}, _claims), do: {:ok, id}
  def subject_for_token(_, _), do: {:error, :invalid_resource}

  def resource_from_claims(%{"sub" => id}) do
    case Auth.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_), do: {:error, :invalid_claims}
end
