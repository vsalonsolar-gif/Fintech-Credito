defmodule CreditSystemWeb.ApplicationLive.Show do
  use CreditSystemWeb, :live_view

  alias CreditSystem.Applications
  alias CreditSystem.Applications.StateMachine

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CreditSystem.PubSub, "application:#{id}")
      Phoenix.PubSub.subscribe(CreditSystem.PubSub, "applications")
    end

    case Applications.get_application(id) do
      {:ok, application} ->
        audit_logs = Applications.get_audit_logs(id)
        available_transitions = StateMachine.available_transitions(application.status)

        {:ok,
         socket
         |> assign(:page_title, "Detalle de Solicitud")
         |> assign(:application, application)
         |> assign(:audit_logs, audit_logs)
         |> assign(:available_transitions, available_transitions)
         |> assign(:confirm_transition, nil)
         |> assign(:last_update, nil)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Solicitud no encontrada")
         |> push_navigate(to: ~p"/applications")}
    end
  end

  @impl true
  def handle_event("confirm_transition", %{"status" => status}, socket) do
    {:noreply, assign(socket, :confirm_transition, status)}
  end

  @impl true
  def handle_event("cancel_transition", _params, socket) do
    {:noreply, assign(socket, :confirm_transition, nil)}
  end

  @impl true
  def handle_event("execute_transition", _params, socket) do
    new_status = socket.assigns.confirm_transition
    application = socket.assigns.application

    case Applications.update_status(application, new_status) do
      {:ok, updated} ->
        audit_logs = Applications.get_audit_logs(updated.id)
        available_transitions = StateMachine.available_transitions(updated.status)

        {:noreply,
         socket
         |> assign(:application, updated)
         |> assign(:audit_logs, audit_logs)
         |> assign(:available_transitions, available_transitions)
         |> assign(:confirm_transition, nil)
         |> assign(:last_update, DateTime.utc_now())
         |> put_flash(:info, "Estado actualizado a: #{status_label(new_status)}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:confirm_transition, nil)
         |> put_flash(:error, "Error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:status_changed, _new_status}, socket), do: reload_application(socket)

  @impl true
  def handle_info({:application_updated, id}, socket) do
    if id == socket.assigns.application.id,
      do: reload_application(socket),
      else: {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp reload_application(socket) do
    case Applications.get_application(socket.assigns.application.id) do
      {:ok, application} ->
        audit_logs = Applications.get_audit_logs(application.id)
        available_transitions = StateMachine.available_transitions(application.status)

        {:noreply,
         socket
         |> assign(:application, application)
         |> assign(:audit_logs, audit_logs)
         |> assign(:available_transitions, available_transitions)
         |> assign(:last_update, DateTime.utc_now())}

      _ ->
        {:noreply, socket}
    end
  end

  # ── Helpers ──

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

  defp transition_btn_class("approved"), do: "btn-success"
  defp transition_btn_class("rejected"), do: "btn-error"
  defp transition_btn_class("disbursed"), do: "btn-accent"
  defp transition_btn_class(_), do: "btn-info"

  defp transition_icon("approved"), do: "hero-check-circle"
  defp transition_icon("rejected"), do: "hero-x-circle"
  defp transition_icon("disbursed"), do: "hero-banknotes"
  defp transition_icon("validating"), do: "hero-magnifying-glass"
  defp transition_icon("under_review"), do: "hero-eye"
  defp transition_icon(_), do: "hero-arrow-right"

  defp transition_description("validating"), do: "Se iniciara la validacion automatica del documento y reglas del pais."
  defp transition_description("under_review"), do: "La solicitud sera enviada a revision manual por un analista."
  defp transition_description("approved"), do: "La solicitud sera aprobada y se procedera al siguiente paso."
  defp transition_description("rejected"), do: "La solicitud sera rechazada. Esta accion no se puede deshacer."
  defp transition_description("disbursed"), do: "Se confirmara el desembolso de los fondos al solicitante."
  defp transition_description(_), do: "Se cambiara el estado de la solicitud."

  defp risk_class(nil), do: "text-base-content/30"
  defp risk_class(s) when s >= 70, do: "text-success"
  defp risk_class(s) when s >= 40, do: "text-warning"
  defp risk_class(_), do: "text-error"

  defp risk_label(nil), do: "Evaluando..."
  defp risk_label(s) when s >= 70, do: "Bajo riesgo"
  defp risk_label(s) when s >= 40, do: "Riesgo moderado"
  defp risk_label(_), do: "Alto riesgo"

  defp risk_progress_class(nil), do: ""
  defp risk_progress_class(s) when s >= 70, do: "progress-success"
  defp risk_progress_class(s) when s >= 40, do: "progress-warning"
  defp risk_progress_class(_), do: "progress-error"

  defp mask_doc(doc) when is_binary(doc) and byte_size(doc) > 4 do
    String.duplicate("*", byte_size(doc) - 4) <> String.slice(doc, -4..-1//1)
  end

  defp mask_doc(doc), do: doc

  defp format_amount(amount, "MX"), do: "$#{format_with_thousands(amount)} MXN"
  defp format_amount(amount, "CO"), do: "$#{format_with_thousands(amount)} COP"
  defp format_amount(amount, _), do: "$#{format_with_thousands(amount)}"

  defp format_with_thousands(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> String.split(".")
    |> (fn parts ->
      case parts do
        [integer, decimal] ->
          "#{add_thousands_separator(integer)},#{decimal}"
        [integer] ->
          "#{add_thousands_separator(integer)},00"
        _ ->
          Decimal.to_string(amount)
      end
    end).()
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

  defp country_name("MX"), do: "Mexico"
  defp country_name("CO"), do: "Colombia"
  defp country_name(_), do: "Desconocido"

  defp flag_url(code) when is_binary(code) do
    "https://flagcdn.com/w40/#{String.downcase(code)}.png"
  end

  defp humanize_key(key), do: key |> String.replace("_", " ") |> String.capitalize()

  defp humanize_action("application_created"), do: "Solicitud Creada"
  defp humanize_action("status_changed"), do: "Cambio de Estado"
  defp humanize_action("risk_evaluation_completed"), do: "Evaluacion de Riesgo Completada"
  defp humanize_action(a), do: a |> String.replace("_", " ") |> String.capitalize()

  defp audit_icon("application_created"), do: "hero-document-plus"
  defp audit_icon("status_changed"), do: "hero-arrow-path"
  defp audit_icon("risk_evaluation_completed"), do: "hero-shield-check"
  defp audit_icon(_), do: "hero-information-circle"

  defp audit_color("application_created"), do: "text-info"
  defp audit_color("status_changed"), do: "text-warning"
  defp audit_color("risk_evaluation_completed"), do: "text-success"
  defp audit_color(_), do: "text-base-content/50"

  defp format_datetime(nil), do: ""
  defp format_datetime(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M UTC")

  defp step_status(current, step_status) do
    order = %{
      "pending" => 0,
      "validating" => 1,
      "under_review" => 2,
      "approved" => 3,
      "disbursed" => 4,
      "rejected" => 3
    }

    current_order = Map.get(order, current, 0)
    step_order = Map.get(order, step_status, 0)
    if step_order <= current_order, do: "step-primary", else: ""
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="animate-fade-in-up">
      <!-- Breadcrumb -->
      <div class="text-sm breadcrumbs mb-6">
        <ul>
          <li><.link navigate={~p"/"}>Inicio</.link></li>
          <li><.link navigate={~p"/applications"}>Solicitudes</.link></li>
          <li class="text-base-content/50 font-mono">{String.slice(@application.id, 0, 8)}...</li>
        </ul>
      </div>

      <!-- Real-time update indicator -->
      <%= if @last_update do %>
        <div class="animate-slide-in mb-4">
          <div class="alert alert-info alert-sm py-2">
            <.icon name="hero-arrow-path" class="size-4" />
            <span class="text-sm">Actualizado en tiempo real - {format_datetime(@last_update)}</span>
          </div>
        </div>
      <% end %>

      <!-- Header Card -->
      <div class="card bg-base-100 shadow-sm mb-6">
        <div class="card-body p-5">
          <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
            <div class="flex items-center gap-4">
              <div class="avatar placeholder">
                <div class="bg-primary/10 text-primary rounded-xl w-14">
                  <span class="text-xl font-bold text-center block">{@application.full_name |> String.slice(0, 2) |> String.upcase()}</span>
                </div>
              </div>

              <div>
                <h1 class="text-xl font-bold">{@application.full_name}</h1>

                <div class="flex flex-wrap items-center gap-2 mt-1">
                  <code class="text-xs bg-base-200 px-2 py-0.5 rounded font-mono">{@application.id}</code>
                  <div class="flex items-center gap-1.5">
                    <img src={flag_url(@application.country)} alt={@application.country} class="w-5 h-auto rounded-sm" />
                    <span class="text-xs font-medium">{country_name(@application.country)}</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <%= if @application.status in ["pending", "validating", "under_review"] do %>
                <div class="w-2 h-2 rounded-full bg-info animate-status-blink" />
              <% end %>
              <div class={"badge badge-lg gap-1 #{status_badge_class(@application.status)}"}>
                {status_label(@application.status)}
              </div>
            </div>
          </div>

          <!-- Status Steps -->
          <div class="mt-6">
            <%= if @application.status == "rejected" do %>
              <ul class="steps steps-horizontal w-full text-xs">
                <li class="step step-primary">Pendiente</li>
                <li class={["step", step_status(@application.status, "validating")]}>Validando</li>
                <li class="step step-error">Rechazada</li>
              </ul>
            <% else %>
              <ul class="steps steps-horizontal w-full text-xs">
                <li class="step step-primary">Pendiente</li>
                <li class={["step", step_status(@application.status, "validating")]}>Validando</li>
                <li class={["step", step_status(@application.status, "under_review")]}>Revision</li>
                <li class={["step", step_status(@application.status, "approved")]}>Aprobada</li>
                <li class={["step", step_status(@application.status, "disbursed")]}>Desembolsada</li>
              </ul>
            <% end %>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left Column -->
        <div class="lg:col-span-2 space-y-6">
          <!-- Application Details -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h2 class="font-semibold text-sm flex items-center gap-2 mb-4">
                <.icon name="hero-document-text" class="size-4 text-primary" /> Detalles de la Solicitud
              </h2>

              <div class="grid grid-cols-2 gap-4">
                <div class="space-y-1">
                  <p class="text-xs text-base-content/40 uppercase tracking-wider">Pais</p>
                  <p class="font-medium text-sm flex items-center gap-1.5">
                    <img src={flag_url(@application.country)} alt={@application.country} class="w-5 h-auto rounded-sm" />
                    {country_name(@application.country)}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs text-base-content/40 uppercase tracking-wider">
                    Documento ({@application.document_type})
                  </p>
                  <p class="font-medium text-sm font-mono">
                    {mask_doc(@application.identity_document)}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs text-base-content/40 uppercase tracking-wider">
                    Monto Solicitado
                  </p>
                  <p class="font-bold text-lg text-primary">
                    {format_amount(@application.requested_amount, @application.country)}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs text-base-content/40 uppercase tracking-wider">Ingreso Mensual</p>
                  <p class="font-medium text-sm">
                    {format_amount(@application.monthly_income, @application.country)}
                  </p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs text-base-content/40 uppercase tracking-wider">
                    Fecha de Solicitud
                  </p>
                  <p class="font-medium text-sm">{@application.application_date}</p>
                </div>

                <div class="space-y-1">
                  <p class="text-xs text-base-content/40 uppercase tracking-wider">Creada</p>
                  <p class="font-medium text-sm">{format_datetime(@application.inserted_at)}</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Banking Info -->
          <%= if @application.banking_info && @application.banking_info != %{} do %>
            <div class="card bg-base-100 shadow-sm">
              <div class="card-body p-5">
                <h2 class="font-semibold text-sm flex items-center gap-2 mb-4">
                  <.icon name="hero-building-library" class="size-4 text-info" /> Informacion Bancaria
                  <span class="badge badge-ghost badge-xs">Proveedor {country_name(@application.country)}</span>
                </h2>

                <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  <%= for {key, value} <- @application.banking_info do %>
                    <div class="bg-base-200/50 rounded-lg p-3">
                      <p class="text-xs text-base-content/40">{humanize_key(key)}</p>
                      <p class="font-medium text-sm mt-0.5">{value}</p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Audit Trail -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h2 class="font-semibold text-sm flex items-center gap-2 mb-4">
                <.icon name="hero-clock" class="size-4 text-warning" /> Historial de Auditoria
                <div class="badge badge-sm badge-ghost">{length(@audit_logs)}</div>
                <div class="flex-1" />
                <div class="flex items-center gap-1.5">
                  <div class="w-1.5 h-1.5 rounded-full bg-success animate-live-pulse" />
                  <span class="text-[10px] text-success font-medium">En vivo</span>
                </div>
              </h2>

              <%= if @audit_logs != [] do %>
                <div class="space-y-0">
                  <%= for {log, idx} <- Enum.with_index(@audit_logs) do %>
                    <div class="flex gap-3">
                      <!-- Timeline line -->
                      <div class="flex flex-col items-center">
                        <div class={"w-8 h-8 rounded-full flex items-center justify-center shrink-0 bg-base-200 #{audit_color(log.action)}"}>
                          <.icon name={audit_icon(log.action)} class="size-4" />
                        </div>

                        <%= if idx < length(@audit_logs) - 1 do %>
                          <div class="w-0.5 h-full bg-base-200 my-1" />
                        <% end %>
                      </div>

                      <div class="pb-5 flex-1">
                        <div class="flex justify-between items-start">
                          <p class="font-medium text-sm">{humanize_action(log.action)}</p>
                          <p class="text-xs text-base-content/40">
                            {format_datetime(log.inserted_at)}
                          </p>
                        </div>

                        <%= if log.old_state || log.new_state do %>
                          <div class="flex items-center gap-1 mt-1">
                            <span class="text-xs text-base-content/50">
                              {status_label(log.old_state || "none")}
                            </span>
                            <.icon name="hero-arrow-right-micro" class="size-3 text-base-content/30" />
                            <div class={"badge badge-xs #{status_badge_class(log.new_state || "")}"}>
                              {status_label(log.new_state || "none")}
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-8 text-base-content/30">
                  <.icon name="hero-clock" class="size-8 mx-auto mb-2" />
                  <p class="text-sm">Sin registros de auditoria aun</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Right Column -->
        <div class="space-y-6">
          <!-- Risk Score -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h3 class="font-semibold text-sm flex items-center gap-2">
                <.icon name="hero-shield-check" class="size-4 text-success" /> Evaluacion de Riesgo
              </h3>

              <div class="text-center py-4">
                <p class={"text-5xl font-bold #{risk_class(@application.risk_score)}"}>
                  {if @application.risk_score, do: @application.risk_score, else: "--"}
                </p>

                <p class={"text-xs mt-1 font-medium #{risk_class(@application.risk_score)}"}>
                  {risk_label(@application.risk_score)}
                </p>

                <p class="text-xs text-base-content/30 mt-0.5">de 100 puntos</p>

                <%= if @application.risk_score do %>
                  <progress
                    class={"progress w-full mt-3 #{risk_progress_class(@application.risk_score)}"}
                    value={@application.risk_score}
                    max="100"
                  />
                <% else %>
                  <div class="flex items-center justify-center gap-2 mt-3 text-xs text-base-content/40">
                    <span class="loading loading-spinner loading-xs" /> Procesando evaluacion...
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Actions -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h3 class="font-semibold text-sm flex items-center gap-2 mb-3">
                <.icon name="hero-bolt" class="size-4 text-accent" /> Acciones
              </h3>

              <%= if @available_transitions != [] do %>
                <div class="space-y-2">
                  <%= for transition <- @available_transitions do %>
                    <button
                      phx-click="confirm_transition"
                      phx-value-status={transition}
                      class={"btn btn-sm w-full gap-2 #{transition_btn_class(transition)}"}
                    >
                      <.icon name={transition_icon(transition)} class="size-4" />
                      Mover a: {status_label(transition)}
                    </button>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-4">
                  <div class="badge badge-lg badge-ghost gap-2">
                    <.icon name="hero-lock-closed-micro" class="size-3" /> Estado final
                  </div>
                  <p class="text-xs text-base-content/40 mt-2">No hay transiciones disponibles</p>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Metadata -->
          <%= if @application.metadata && @application.metadata != %{} do %>
            <div class="card bg-base-100 shadow-sm">
              <div class="card-body p-5">
                <h3 class="font-semibold text-sm flex items-center gap-2 mb-3">
                  <.icon name="hero-tag" class="size-4 text-base-content/50" /> Metadata
                </h3>

                <div class="space-y-2">
                  <%= for {key, value} <- @application.metadata do %>
                    <div class="flex justify-between text-xs">
                      <span class="text-base-content/50">{humanize_key(to_string(key))}</span>
                      <span class="font-medium font-mono">{value}</span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Navigation -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <.link navigate={~p"/applications"} class="btn btn-ghost btn-sm w-full gap-2">
                <.icon name="hero-arrow-left" class="size-4" />
                Volver a solicitudes
              </.link>
            </div>
          </div>
        </div>
      </div>

      <!-- Confirmation Modal -->
      <%= if @confirm_transition do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
          <!-- Backdrop -->
          <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" phx-click="cancel_transition" />

          <!-- Modal -->
          <div class="card bg-base-100 shadow-2xl w-full max-w-md relative z-10 animate-fade-in-up">
            <div class="card-body p-6">
              <div class="flex items-center gap-3 mb-4">
                <div class={"w-12 h-12 rounded-xl flex items-center justify-center #{
                  case @confirm_transition do
                    "rejected" -> "bg-error/10"
                    "approved" -> "bg-success/10"
                    "disbursed" -> "bg-accent/10"
                    _ -> "bg-info/10"
                  end
                }"}>
                  <.icon name={transition_icon(@confirm_transition)} class={"size-6 #{
                    case @confirm_transition do
                      "rejected" -> "text-error"
                      "approved" -> "text-success"
                      "disbursed" -> "text-accent"
                      _ -> "text-info"
                    end
                  }"} />
                </div>
                <div>
                  <h3 class="font-bold text-lg">Confirmar Transicion</h3>
                  <p class="text-sm text-base-content/50">
                    {@application.full_name}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2 mb-4 p-3 rounded-lg bg-base-200">
                <div class={"badge badge-sm #{status_badge_class(@application.status)}"}>
                  {status_label(@application.status)}
                </div>
                <.icon name="hero-arrow-right" class="size-4 text-base-content/30" />
                <div class={"badge badge-sm #{status_badge_class(@confirm_transition)}"}>
                  {status_label(@confirm_transition)}
                </div>
              </div>

              <p class="text-sm text-base-content/70 mb-6">
                {transition_description(@confirm_transition)}
              </p>

              <div class="flex gap-3 justify-end">
                <button phx-click="cancel_transition" class="btn btn-ghost btn-sm">
                  Cancelar
                </button>
                <button
                  phx-click="execute_transition"
                  class={"btn btn-sm gap-2 #{transition_btn_class(@confirm_transition)}"}
                >
                  <.icon name={transition_icon(@confirm_transition)} class="size-4" />
                  Confirmar
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
