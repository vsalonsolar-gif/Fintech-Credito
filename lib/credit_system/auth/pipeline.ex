defmodule CreditSystem.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :credit_system,
    error_handler: CreditSystem.Auth.ErrorHandler,
    module: CreditSystem.Auth.Guardian

  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
