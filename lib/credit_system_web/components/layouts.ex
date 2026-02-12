defmodule CreditSystemWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CreditSystemWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-base-200">
      <!-- Mobile Header -->
      <div class="lg:hidden fixed top-0 left-0 right-0 z-30 bg-base-300/95 backdrop-blur-md border-b border-base-content/10">
        <div class="flex items-center justify-between px-4 h-14">
          <a href="/" class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <.icon name="hero-banknotes" class="size-5 text-primary-content" />
            </div>
            <span class="font-bold text-base">CreditSys</span>
          </a>

          <div class="flex items-center gap-2">
            <div class="flex items-center gap-1.5 px-2 py-1 rounded-full bg-success/10">
              <div class="w-1.5 h-1.5 rounded-full bg-success animate-live-pulse" />
              <span class="text-[10px] font-medium text-success">EN VIVO</span>
            </div>

            <label for="mobile-drawer" class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-bars-3" class="size-5" />
            </label>
          </div>
        </div>
      </div>

      <!-- Mobile Drawer -->
      <input type="checkbox" id="mobile-drawer" class="hidden peer" />
      <div class="fixed inset-0 z-40 hidden peer-checked:block lg:hidden">
        <label for="mobile-drawer" class="absolute inset-0 bg-black/50 sidebar-overlay" />
        <aside class="absolute left-0 top-0 h-full w-72 bg-base-300 shadow-2xl flex flex-col animate-slide-in">
          <div class="p-5 border-b border-base-content/10 flex items-center justify-between">
            <a href="/" class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-xl bg-primary flex items-center justify-center">
                <.icon name="hero-banknotes" class="size-6 text-primary-content" />
              </div>
              <div>
                <h1 class="font-bold text-lg leading-tight">CreditSys</h1>
                <p class="text-xs text-base-content/50">Plataforma Fintech</p>
              </div>
            </a>
            <label for="mobile-drawer" class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-x-mark" class="size-5" />
            </label>
          </div>

          <nav class="flex-1 p-4 space-y-1">
            <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-3 px-3">
              Menu
            </p>
            <label for="mobile-drawer">
              <a
                href="/applications"
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium hover:bg-base-100 transition-colors group"
              >
                <.icon name="hero-document-text" class="size-5 text-base-content/50 group-hover:text-primary" />
                <span>Solicitudes</span>
              </a>
            </label>
            <label for="mobile-drawer">
              <a
                href="/"
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium hover:bg-base-100 transition-colors group"
              >
                <.icon name="hero-plus-circle" class="size-5 text-base-content/50 group-hover:text-primary" />
                <span>Nueva Solicitud</span>
              </a>
            </label>
          </nav>

          <div class="p-4 border-t border-base-content/10 space-y-3">
            <div class="flex items-center justify-between px-2">
              <span class="text-xs text-base-content/40">Tema</span>
              <.theme_toggle />
            </div>
          </div>
        </aside>
      </div>

      <!-- Desktop Sidebar -->
      <aside class="hidden lg:flex w-64 bg-base-300 border-r border-base-content/10 flex-col fixed h-full z-20">
        <!-- Logo -->
        <div class="p-5 border-b border-base-content/10">
          <a href="/" class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-primary flex items-center justify-center shadow-lg shadow-primary/20">
              <.icon name="hero-banknotes" class="size-6 text-primary-content" />
            </div>
            <div>
              <h1 class="font-bold text-lg leading-tight">CreditSys</h1>
              <p class="text-xs text-base-content/50">Plataforma Fintech</p>
            </div>
          </a>
        </div>

        <!-- Navigation -->
        <nav class="flex-1 p-4 space-y-1">
          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-3 px-3">
            Menu
          </p>
          <a
            href="/applications"
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium hover:bg-base-100 transition-colors group"
          >
            <.icon name="hero-document-text" class="size-5 text-base-content/50 group-hover:text-primary" />
            <span>Solicitudes</span>
          </a>
          <a
            href="/"
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium hover:bg-base-100 transition-colors group"
          >
            <.icon name="hero-plus-circle" class="size-5 text-base-content/50 group-hover:text-primary" />
            <span>Nueva Solicitud</span>
          </a>

          <div class="divider my-4" />

          <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-3 px-3">
            Sistema
          </p>
          <a
            href="/dev/dashboard"
            class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium hover:bg-base-100 transition-colors group"
          >
            <.icon name="hero-chart-bar" class="size-5 text-base-content/50 group-hover:text-primary" />
            <span>Dashboard</span>
          </a>
        </nav>

        <!-- Live Status + Theme Toggle + Footer -->
        <div class="p-4 border-t border-base-content/10 space-y-3">
          <!-- Live Connection Indicator -->
          <div class="flex items-center gap-2 px-3 py-2 rounded-lg bg-success/5 border border-success/10">
            <div class="w-2 h-2 rounded-full bg-success animate-live-pulse" />
            <span class="text-xs font-medium text-success/80">Conectado en tiempo real</span>
          </div>

          <div class="flex items-center justify-between px-2">
            <span class="text-xs text-base-content/40">Tema</span>
            <.theme_toggle />
          </div>
          <div class="px-2 flex items-center justify-between">
            <p class="text-xs text-base-content/30">v1.0.0</p>
            <p class="text-xs text-base-content/30">Phoenix + LiveView</p>
          </div>
        </div>
      </aside>

      <!-- Main Content -->
      <main class="flex-1 lg:ml-64 pt-14 lg:pt-0">
        <div class="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Conexion perdida")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Intentando reconectar")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Algo salio mal")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Intentando reconectar")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
