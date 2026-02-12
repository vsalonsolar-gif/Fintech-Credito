# Seeds for CreditSystem
alias CreditSystem.Repo
alias CreditSystem.Auth.User
alias CreditSystem.Applications.CreditApplication

IO.puts("Seeding database...")

# Create admin user
admin =
  case Repo.get_by(User, email: "admin@creditsystem.com") do
    nil ->
      {:ok, user} =
        %User{}
        |> User.changeset(%{email: "admin@creditsystem.com", password: "admin123", role: "admin"})
        |> Repo.insert()

      user

    user ->
      user
  end

IO.puts("Created admin user: admin@creditsystem.com / admin123")

# Create analyst user
analyst =
  case Repo.get_by(User, email: "analyst@creditsystem.com") do
    nil ->
      {:ok, user} =
        %User{}
        |> User.changeset(%{
          email: "analyst@creditsystem.com",
          password: "analyst123",
          role: "analyst"
        })
        |> Repo.insert()

      user

    user ->
      user
  end

IO.puts("Created analyst user: analyst@creditsystem.com / analyst123")

# Sample MX applications
mx_apps = [
  %{
    country: "MX",
    full_name: "Carlos García López",
    identity_document: "GALC900101HDFRRL09",
    document_type: "CURP",
    requested_amount: Decimal.new("150000"),
    monthly_income: Decimal.new("45000"),
    application_date: Date.utc_today(),
    status: "approved",
    risk_score: 78,
    user_id: admin.id
  },
  %{
    country: "MX",
    full_name: "María Fernanda Rodríguez",
    identity_document: "ROFM850515MDFRDR02",
    document_type: "CURP",
    requested_amount: Decimal.new("300000"),
    monthly_income: Decimal.new("80000"),
    application_date: Date.utc_today(),
    status: "under_review",
    risk_score: 65,
    user_id: analyst.id
  },
  %{
    country: "MX",
    full_name: "José Luis Martínez",
    identity_document: "MALJ780220HDFRRS08",
    document_type: "CURP",
    requested_amount: Decimal.new("50000"),
    monthly_income: Decimal.new("25000"),
    application_date: Date.add(Date.utc_today(), -5),
    status: "disbursed",
    risk_score: 85,
    user_id: admin.id
  }
]

# Sample CO applications
co_apps = [
  %{
    country: "CO",
    full_name: "Andrés Felipe Gómez",
    identity_document: "1020345678",
    document_type: "CC",
    requested_amount: Decimal.new("50000000"),
    monthly_income: Decimal.new("8000000"),
    application_date: Date.utc_today(),
    status: "approved",
    risk_score: 72,
    user_id: admin.id
  },
  %{
    country: "CO",
    full_name: "Laura Valentina Díaz",
    identity_document: "52987654",
    document_type: "CC",
    requested_amount: Decimal.new("120000000"),
    monthly_income: Decimal.new("15000000"),
    application_date: Date.utc_today(),
    status: "pending",
    user_id: analyst.id
  },
  %{
    country: "CO",
    full_name: "Santiago Ramírez",
    identity_document: "80123456",
    document_type: "CC",
    requested_amount: Decimal.new("30000000"),
    monthly_income: Decimal.new("5000000"),
    application_date: Date.add(Date.utc_today(), -3),
    status: "rejected",
    risk_score: 25,
    user_id: admin.id
  }
]

for attrs <- mx_apps ++ co_apps do
  %CreditApplication{}
  |> CreditApplication.changeset(attrs)
  |> Repo.insert!()
end

IO.puts("Created #{length(mx_apps)} MX applications and #{length(co_apps)} CO applications")
IO.puts("Seeding complete!")
