defmodule CreditSystem.Repo do
  use Ecto.Repo,
    otp_app: :credit_system,
    adapter: Ecto.Adapters.Postgres
end
