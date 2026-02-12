defmodule CreditSystem.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CreditSystemWeb.Telemetry,
      CreditSystem.Repo,
      {DNSCluster, query: Application.get_env(:credit_system, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CreditSystem.PubSub},
      # Finch HTTP client for webhooks
      {Finch, name: CreditSystem.Finch},
      # Cachex for caching
      {Cachex, name: :credit_system_cache},
      # Oban job queue
      {Oban, Application.fetch_env!(:credit_system, Oban)},
      # Start to serve requests, typically the last entry
      CreditSystemWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CreditSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CreditSystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
