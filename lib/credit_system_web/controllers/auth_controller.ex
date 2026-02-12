defmodule CreditSystemWeb.AuthController do
  use CreditSystemWeb, :controller

  alias CreditSystem.Auth

  action_fallback CreditSystemWeb.FallbackController

  def register(conn, %{"email" => email, "password" => password} = params) do
    attrs = %{
      email: email,
      password: password,
      role: params["role"] || "analyst"
    }

    with {:ok, user} <- Auth.register_user(attrs),
         {:ok, token} <- Auth.generate_token(user) do
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          user: %{id: user.id, email: user.email, role: user.role},
          token: token
        }
      })
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- Auth.authenticate_user(email, password),
         {:ok, token} <- Auth.generate_token(user) do
      conn
      |> json(%{
        data: %{
          user: %{id: user.id, email: user.email, role: user.role},
          token: token
        }
      })
    else
      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end
end
