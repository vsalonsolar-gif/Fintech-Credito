defmodule CreditSystemWeb.Router do
  use CreditSystemWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CreditSystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug CreditSystem.Auth.Pipeline
  end

  # LiveView routes (browser)
  scope "/", CreditSystemWeb do
    pipe_through :browser

    live "/", ApplicationLive.Index, :index
    live "/applications", ApplicationLive.Index, :index
    live "/applications/new", ApplicationLive.Form, :new
    live "/applications/:id", ApplicationLive.Show, :show
  end

  # Public API routes (auth)
  scope "/api", CreditSystemWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login

    # Incoming webhooks (authenticated via webhook secret)
    post "/webhooks/banking", WebhookController, :banking_update
  end

  # Protected API routes
  scope "/api", CreditSystemWeb do
    pipe_through :authenticated_api

    resources "/applications", ApplicationController, only: [:index, :show, :create]
    patch "/applications/:id/status", ApplicationController, :update_status
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:credit_system, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CreditSystemWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
