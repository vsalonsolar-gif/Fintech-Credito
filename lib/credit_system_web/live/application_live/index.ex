defmodule CreditSystemWeb.ApplicationLive.Index do
  use CreditSystemWeb, :live_view

  alias CreditSystem.Applications

  @countries [
    %{code: "MX", name: "Mexico", currency: "MXN", doc: "CURP", enabled: true},
    %{code: "CO", name: "Colombia", currency: "COP", doc: "CC", enabled: true},
    %{code: "ES", name: "España", currency: "EUR", doc: "DNI", enabled: false},
    %{code: "PT", name: "Portugal", currency: "EUR", doc: "NIF", enabled: false},
    %{code: "IT", name: "Italia", currency: "EUR", doc: "CF", enabled: false},
    %{code: "BR", name: "Brasil", currency: "BRL", doc: "CPF", enabled: false}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CreditSystem.PubSub, "applications")
    end

    view_mode = Map.get(socket.assigns, :view_mode, :country_selection)

    case view_mode do
      :country_selection ->
        {:ok,
         socket
         |> assign(:page_title, "Selecciona tu Pais")
         |> assign(:view_mode, :country_selection)
         |> assign(:countries, @countries)}

      :applications ->
        applications = Applications.list_applications()

        {:ok,
         socket
         |> assign(:page_title, "Solicitudes de Credito")
         |> assign(:applications, applications)
         |> assign(:country_filter, "")
         |> assign(:status_filter, "")
         |> assign(:search_query, "")
         |> assign(:view_mode, :applications)
         |> assign(:realtime_events, [])
         |> assign(:countries, @countries)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_country", %{"country" => country}, socket) do
    {:noreply,
     socket
     |> push_navigate(to: "/applications/new?country=#{country}")}
  end

  @impl true
  def handle_event("view_applications", _params, socket) do
    applications = Applications.list_applications()

    {:noreply,
     socket
     |> assign(:view_mode, :applications)
     |> assign(:page_title, "Solicitudes de Credito")
     |> assign(:applications, applications)
     |> assign(:country_filter, "")
     |> assign(:status_filter, "")
     |> assign(:search_query, "")
     |> assign(:realtime_events, [])}
  end

  @impl true
  def handle_event("filter", params, socket) do
    country = Map.get(params, "country", "")
    status = Map.get(params, "status", "")
    search = Map.get(params, "search", "")

    filters = %{"country" => country, "status" => status}
    applications = Applications.list_applications(filters)

    # Client-side search filtering
    applications =
      if search != "" do
        search_lower = String.downcase(search)

        Enum.filter(applications, fn app ->
          String.contains?(String.downcase(app.full_name), search_lower) or
            String.contains?(String.downcase(app.identity_document || ""), search_lower) or
            String.contains?(String.downcase(app.id), search_lower)
        end)
      else
        applications
      end

    {:noreply,
     socket
     |> assign(:applications, applications)
     |> assign(:country_filter, country)
     |> assign(:status_filter, status)
     |> assign(:search_query, search)}
  end

  @impl true
  def handle_event("dismiss_event", %{"index" => index}, socket) do
    idx = String.to_integer(index)
    events = List.delete_at(socket.assigns.realtime_events, idx)
    {:noreply, assign(socket, :realtime_events, events)}
  end

  @impl true
  def handle_info({:application_created, _id}, socket) do
    applications = reload_applications(socket)

    event = %{
      type: :created,
      message: "Nueva solicitud recibida",
      timestamp: DateTime.utc_now()
    }

    events = [event | Enum.take(socket.assigns[:realtime_events] || [], 4)]

    {:noreply,
     socket
     |> assign(:applications, applications)
     |> assign(:realtime_events, events)
     |> put_flash(:info, "Nueva solicitud recibida en tiempo real")}
  end

  @impl true
  def handle_info({:application_updated, _id}, socket) do
    applications = reload_applications(socket)

    event = %{
      type: :updated,
      message: "Solicitud actualizada",
      timestamp: DateTime.utc_now()
    }

    events = [event | Enum.take(socket.assigns[:realtime_events] || [], 4)]

    {:noreply,
     socket
     |> assign(:applications, applications)
     |> assign(:realtime_events, events)}
  end

  defp reload_applications(socket) do
    Applications.list_applications(%{
      "country" => socket.assigns[:country_filter] || "",
      "status" => socket.assigns[:status_filter] || ""
    })
  end

  defp count_by_status(apps, statuses) when is_list(statuses) do
    Enum.count(apps, &(&1.status in statuses))
  end

  defp count_by_status(apps, status) do
    Enum.count(apps, &(&1.status == status))
  end

  defp total_amount(apps) do
    apps
    |> Enum.reduce(Decimal.new(0), fn app, acc -> Decimal.add(acc, app.requested_amount) end)
    |> format_compact_number()
  end

  defp format_compact_number(num) do
    n = Decimal.to_float(num)

    cond do
      n >= 1_000_000_000 -> "#{Float.round(n / 1_000_000_000, 1)}B"
      n >= 1_000_000 -> "#{Float.round(n / 1_000_000, 1)}M"
      n >= 1_000 -> "#{Float.round(n / 1_000, 1)}K"
      true -> "#{round(n)}"
    end
  end

  defp flag_url(code) do
    "https://flagcdn.com/w40/#{String.downcase(code)}.png"
  end

  defp status_badge_class("pending"), do: "badge-ghost"
  defp status_badge_class("validating"), do: "badge-info"
  defp status_badge_class("under_review"), do: "badge-warning"
  defp status_badge_class("approved"), do: "badge-success"
  defp status_badge_class("rejected"), do: "badge-error"
  defp status_badge_class("disbursed"), do: "badge-accent"
  defp status_badge_class(_), do: "badge-ghost"

  defp status_label("pending"), do: "Pendiente"
  defp status_label("validating"), do: "Validando"
  defp status_label("under_review"), do: "En Revision"
  defp status_label("approved"), do: "Aprobada"
  defp status_label("rejected"), do: "Rechazada"
  defp status_label("disbursed"), do: "Desembolsada"
  defp status_label(s), do: s

  defp mask_doc(doc) when is_binary(doc) and byte_size(doc) > 4 do
    String.duplicate("*", byte_size(doc) - 4) <> String.slice(doc, -4..-1//1)
  end

  defp mask_doc(doc), do: doc

  defp format_amount(amount, "MX"), do: "$#{format_with_thousands(amount)} MXN"
  defp format_amount(amount, "CO"), do: "$#{format_with_thousands(amount)} COP"
  defp format_amount(amount, _), do: "$#{format_with_thousands(amount)}"

  defp format_with_thousands(amount) do
    amount
    |> Decimal.round(0)
    |> Decimal.to_string()
    |> add_thousands_separator()
  end

  defp add_thousands_separator(str) when is_binary(str) do
    str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&(&1 |> Enum.reverse() |> Enum.join()))
    |> Enum.reverse()
    |> Enum.join(".")
  end

  defp risk_badge_class(nil), do: "text-base-content/30"
  defp risk_badge_class(score) when score >= 70, do: "text-success"
  defp risk_badge_class(score) when score >= 40, do: "text-warning"
  defp risk_badge_class(_), do: "text-error"

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 5 -> "ahora"
      diff < 60 -> "hace #{diff}s"
      diff < 3600 -> "hace #{div(diff, 60)}m"
      true -> "hace #{div(diff, 3600)}h"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @view_mode == :country_selection do %>
      <div class="min-h-[80vh] flex items-center justify-center p-4">
        <div class="w-full max-w-4xl animate-fade-in-up">
          <!-- Hero Section -->
          <div class="text-center mb-10">
            <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 border border-primary/20 mb-6">
              <div class="w-2 h-2 rounded-full bg-primary animate-live-pulse" />
              <span class="text-xs font-medium text-primary">Plataforma Multipaís</span>
            </div>

            <h1 class="text-4xl sm:text-5xl font-bold mb-4 bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
              Solicita tu Credito
            </h1>

            <p class="text-lg text-base-content/60 max-w-md mx-auto">
              Selecciona tu pais para comenzar el proceso de solicitud
            </p>
          </div>

          <!-- Country Grid -->
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-8">
            <%= for country <- @countries do %>
              <%= if country.enabled do %>
                <div
                  class="country-card cursor-pointer card bg-base-100 shadow-md hover:shadow-xl"
                  phx-click="select_country"
                  phx-value-country={country.code}
                >
                  <div class="card-body items-center text-center p-6">
                    <img src={flag_url(country.code)} alt={country.name} class="w-10 h-auto rounded shadow-sm mb-2" />
                    <h2 class="font-bold text-lg">{country.name}</h2>
                    <p class="text-xs text-base-content/50">{country.currency} | {country.doc}</p>
                    <div class="mt-3">
                      <span class="btn btn-primary btn-sm">Solicitar</span>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="card bg-base-100/50 shadow-sm opacity-60 cursor-not-allowed">
                  <div class="card-body items-center text-center p-6">
                    <img src={flag_url(country.code)} alt={country.name} class="w-10 h-auto rounded shadow-sm mb-2 grayscale opacity-50" />
                    <h2 class="font-bold text-lg text-base-content/50">{country.name}</h2>
                    <p class="text-xs text-base-content/30">{country.currency} | {country.doc}</p>
                    <div class="mt-3">
                      <span class="badge badge-outline badge-sm">Proximamente</span>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Quick Access to Applications List -->
          <div class="text-center">
            <button phx-click="view_applications" class="btn btn-ghost btn-sm gap-2 text-base-content/60">
              <.icon name="hero-document-text" class="size-4" />
              Ver solicitudes existentes
              <.icon name="hero-arrow-right" class="size-3" />
            </button>
          </div>

          <!-- Benefits Section -->
          <div class="mt-10 pt-8 border-t border-base-content/10">
            <div class="grid grid-cols-1 sm:grid-cols-4 gap-6">
              <div class="text-center">
                <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mx-auto mb-3">
                  <.icon name="hero-bolt" class="size-6 text-primary" />
                </div>
                <p class="text-sm font-medium">Rapido</p>
                <p class="text-xs text-base-content/50 mt-1">Decision en minutos</p>
              </div>

              <div class="text-center">
                <div class="w-12 h-12 rounded-xl bg-success/10 flex items-center justify-center mx-auto mb-3">
                  <.icon name="hero-shield-check" class="size-6 text-success" />
                </div>
                <p class="text-sm font-medium">Seguro</p>
                <p class="text-xs text-base-content/50 mt-1">Datos protegidos</p>
              </div>

              <div class="text-center">
                <div class="w-12 h-12 rounded-xl bg-info/10 flex items-center justify-center mx-auto mb-3">
                  <.icon name="hero-globe-alt" class="size-6 text-info" />
                </div>
                <p class="text-sm font-medium">Multipaís</p>
                <p class="text-xs text-base-content/50 mt-1">6 paises disponibles</p>
              </div>

              <div class="text-center">
                <div class="w-12 h-12 rounded-xl bg-warning/10 flex items-center justify-center mx-auto mb-3">
                  <.icon name="hero-clock" class="size-6 text-warning" />
                </div>
                <p class="text-sm font-medium">Tiempo Real</p>
                <p class="text-xs text-base-content/50 mt-1">Seguimiento en vivo</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% else %>
      <div class="animate-fade-in-up">
        <!-- Real-time Events Toast -->
        <%= if @realtime_events != [] do %>
          <div class="fixed top-4 right-4 z-50 space-y-2 lg:top-4 lg:right-8">
            <%= for {event, idx} <- Enum.with_index(@realtime_events) do %>
              <div class="animate-toast-in flex items-center gap-3 px-4 py-3 rounded-xl bg-base-100 shadow-lg border border-base-content/10 min-w-[280px]">
                <div class={[
                  "w-2 h-2 rounded-full shrink-0",
                  if(event.type == :created, do: "bg-success", else: "bg-info")
                ]} />
                <div class="flex-1">
                  <p class="text-sm font-medium">{event.message}</p>
                  <p class="text-xs text-base-content/40">{time_ago(event.timestamp)}</p>
                </div>
                <button
                  phx-click="dismiss_event"
                  phx-value-index={idx}
                  class="btn btn-ghost btn-xs btn-square"
                >
                  <.icon name="hero-x-mark-micro" class="size-3" />
                </button>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Page Header -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
          <div>
            <div class="flex items-center gap-3">
              <h1 class="text-2xl font-bold">Solicitudes de Credito</h1>
              <div class="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-success/10 border border-success/20">
                <div class="w-1.5 h-1.5 rounded-full bg-success animate-status-blink" />
                <span class="text-[10px] font-semibold text-success uppercase tracking-wider">En vivo</span>
              </div>
            </div>

            <p class="text-sm text-base-content/50 mt-1">
              Gestiona y monitorea solicitudes en tiempo real
            </p>
          </div>

          <div class="flex gap-2">
            <.link navigate={~p"/"} class="btn btn-ghost btn-sm gap-1">
              <.icon name="hero-globe-alt" class="size-4" /> Paises
            </.link>
            <.link navigate={~p"/"} class="btn btn-primary btn-sm gap-2">
              <.icon name="hero-plus" class="size-4" /> Nueva Solicitud
            </.link>
          </div>
        </div>

        <!-- Stats Cards -->
        <div class="grid grid-cols-2 lg:grid-cols-5 gap-3 mb-6">
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
                  <.icon name="hero-document-text" class="size-5 text-primary" />
                </div>
                <div>
                  <p class="text-2xl font-bold animate-count-up">{length(@applications)}</p>
                  <p class="text-xs text-base-content/50">Total</p>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-warning/10 flex items-center justify-center">
                  <.icon name="hero-clock" class="size-5 text-warning" />
                </div>
                <div>
                  <p class="text-2xl font-bold animate-count-up">
                    {count_by_status(@applications, ["pending", "validating", "under_review"])}
                  </p>
                  <p class="text-xs text-base-content/50">En Proceso</p>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-success/10 flex items-center justify-center">
                  <.icon name="hero-check-circle" class="size-5 text-success" />
                </div>
                <div>
                  <p class="text-2xl font-bold animate-count-up">{count_by_status(@applications, "approved")}</p>
                  <p class="text-xs text-base-content/50">Aprobadas</p>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-error/10 flex items-center justify-center">
                  <.icon name="hero-x-circle" class="size-5 text-error" />
                </div>
                <div>
                  <p class="text-2xl font-bold animate-count-up">{count_by_status(@applications, "rejected")}</p>
                  <p class="text-xs text-base-content/50">Rechazadas</p>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-sm col-span-2 lg:col-span-1">
            <div class="card-body p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center">
                  <.icon name="hero-currency-dollar" class="size-5 text-accent" />
                </div>
                <div>
                  <p class="text-2xl font-bold animate-count-up">${total_amount(@applications)}</p>
                  <p class="text-xs text-base-content/50">Volumen Total</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Filters & Search -->
        <div class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body p-4">
            <form phx-change="filter" class="flex flex-col sm:flex-row gap-3 items-end">
              <!-- Search -->
              <div class="form-control flex-1">
                <label class="label py-1">
                  <span class="label-text text-xs font-medium">Buscar</span>
                </label>
                <label class="input input-bordered input-sm flex items-center gap-2">
                  <.icon name="hero-magnifying-glass" class="size-4 text-base-content/30" />
                  <input
                    type="text"
                    name="search"
                    value={@search_query}
                    placeholder="Nombre, documento o ID..."
                    class="grow bg-transparent outline-none"
                    phx-debounce="300"
                  />
                </label>
              </div>

              <div class="form-control">
                <label class="label py-1">
                  <span class="label-text text-xs font-medium">Pais</span>
                </label>
                <select name="country" class="select select-bordered select-sm w-full sm:w-40">
                  <option value="">Todos los paises</option>
                  <option value="MX" selected={@country_filter == "MX"}>Mexico (MX)</option>
                  <option value="CO" selected={@country_filter == "CO"}>Colombia (CO)</option>
                </select>
              </div>

              <div class="form-control">
                <label class="label py-1">
                  <span class="label-text text-xs font-medium">Estado</span>
                </label>
                <select name="status" class="select select-bordered select-sm w-full sm:w-40">
                  <option value="">Todos los estados</option>
                  <option value="pending" selected={@status_filter == "pending"}>Pendiente</option>
                  <option value="validating" selected={@status_filter == "validating"}>Validando</option>
                  <option value="under_review" selected={@status_filter == "under_review"}>En Revision</option>
                  <option value="approved" selected={@status_filter == "approved"}>Aprobada</option>
                  <option value="rejected" selected={@status_filter == "rejected"}>Rechazada</option>
                  <option value="disbursed" selected={@status_filter == "disbursed"}>Desembolsada</option>
                </select>
              </div>

              <%= if @country_filter != "" or @status_filter != "" or @search_query != "" do %>
                <div class="badge badge-neutral gap-1 self-end mb-1">
                  <.icon name="hero-funnel-micro" class="size-3" /> Filtrado
                </div>
              <% end %>
            </form>
          </div>
        </div>

        <!-- Table -->
        <div class="card bg-base-100 shadow-sm overflow-hidden">
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr class="border-b border-base-200">
                  <th class="font-semibold text-base-content/70">Solicitante</th>
                  <th class="font-semibold text-base-content/70">Pais</th>
                  <th class="font-semibold text-base-content/70 hidden sm:table-cell">Documento</th>
                  <th class="font-semibold text-base-content/70">Monto</th>
                  <th class="font-semibold text-base-content/70">Estado</th>
                  <th class="font-semibold text-base-content/70 hidden md:table-cell">Riesgo</th>
                  <th class="font-semibold text-base-content/70 hidden lg:table-cell">Fecha</th>
                  <th class="font-semibold text-base-content/70"></th>
                </tr>
              </thead>

              <tbody>
                <%= for app <- @applications do %>
                  <tr class="hover border-b border-base-200/50 cursor-pointer transition-colors" id={"app-#{app.id}"}>
                    <td>
                      <div class="flex items-center gap-3">
                        <div class="avatar placeholder">
                          <div class="bg-primary/10 text-primary rounded-lg w-9">
                            <span class="text-xl font-bold text-center block">{app.full_name |> String.slice(0, 2) |> String.upcase()}</span>
                          </div>
                        </div>
                        <div>
                          <p class="font-medium text-sm">{app.full_name}</p>
                          <p class="text-xs text-base-content/40 font-mono">{String.slice(app.id, 0, 8)}</p>
                        </div>
                      </div>
                    </td>

                    <td>
                      <div class="flex items-center gap-1.5">
                        <img src={flag_url(app.country)} alt={app.country} class="w-5 h-auto rounded-sm" />
                        <span class="text-xs font-medium">{app.country}</span>
                      </div>
                    </td>

                    <td class="hidden sm:table-cell">
                      <code class="text-xs bg-base-200 px-2 py-0.5 rounded font-mono">
                        {mask_doc(app.identity_document)}
                      </code>
                    </td>

                    <td class="font-mono text-sm font-medium">
                      {format_amount(app.requested_amount, app.country)}
                    </td>

                    <td>
                      <div class={"badge badge-sm gap-1 #{status_badge_class(app.status)}"}>
                        <%= if app.status in ["pending", "validating"] do %>
                          <div class="w-1.5 h-1.5 rounded-full bg-current animate-status-blink" />
                        <% end %>
                        {status_label(app.status)}
                      </div>
                    </td>

                    <td class="hidden md:table-cell">
                      <span class={"font-mono text-sm font-bold #{risk_badge_class(app.risk_score)}"}>
                        {if app.risk_score, do: "#{app.risk_score}", else: "--"}
                      </span>
                    </td>

                    <td class="text-xs text-base-content/50 hidden lg:table-cell">{app.application_date}</td>

                    <td>
                      <.link navigate={~p"/applications/#{app.id}"} class="btn btn-ghost btn-xs gap-1">
                        Ver <.icon name="hero-arrow-right-micro" class="size-3" />
                      </.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <!-- Empty State -->
          <%= if @applications == [] do %>
            <div class="flex flex-col items-center justify-center py-16 gap-4">
              <div class="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center">
                <.icon name="hero-document-text" class="size-8 text-base-content/20" />
              </div>
              <div class="text-center">
                <p class="font-medium text-base-content/50">No se encontraron solicitudes</p>
                <p class="text-sm text-base-content/30 mt-1">
                  <%= if @search_query != "" or @country_filter != "" or @status_filter != "" do %>
                    Intenta ajustar los filtros de busqueda
                  <% else %>
                    Crea una nueva solicitud para comenzar
                  <% end %>
                </p>
              </div>
              <.link navigate={~p"/"} class="btn btn-primary btn-sm mt-2">
                <.icon name="hero-plus" class="size-4" /> Crear Solicitud
              </.link>
            </div>
          <% end %>

          <!-- Results count -->
          <%= if @applications != [] do %>
            <div class="px-4 py-3 border-t border-base-200 flex items-center justify-between text-xs text-base-content/40">
              <span>Mostrando {length(@applications)} solicitud(es)</span>
              <div class="flex items-center gap-1.5">
                <div class="w-1.5 h-1.5 rounded-full bg-success animate-live-pulse" />
                <span>Actualizacion automatica</span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end
end
