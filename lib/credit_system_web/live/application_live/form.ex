defmodule CreditSystemWeb.ApplicationLive.Form do
  use CreditSystemWeb, :live_view

  alias CreditSystem.Applications
  alias CreditSystem.Applications.CreditApplication

  @country_config %{
    "MX" => %{
      name: "Mexico",
      currency: "MXN",
      doc_name: "CURP",
      doc_placeholder: "ABCD123456HDFXXX0",
      doc_hint: "18 caracteres: 4 letras + 6 digitos + genero + 5 letras + verificacion",
      max_amount: "$500,000 MXN",
      rules: [
        "El ingreso debe ser al menos 3x el pago mensual estimado",
        "Montos mayores a $250,000 requieren revision adicional",
        "Maximo: $500,000 MXN"
      ]
    },
    "CO" => %{
      name: "Colombia",
      currency: "COP",
      doc_name: "Cedula de Ciudadania (CC)",
      doc_placeholder: "1234567890",
      doc_hint: "6 a 10 digitos",
      max_amount: "$200,000,000 COP",
      rules: [
        "La relacion deuda-ingreso debe estar por debajo del 40%",
        "Montos mayores a $100M requieren revision adicional",
        "Maximo: $200,000,000 COP"
      ]
    }
  }

  @impl true
  def mount(%{"country" => country}, _session, socket) do
    country = String.upcase(country)
    changeset = CreditApplication.changeset(%CreditApplication{}, %{"country" => country})

    {:ok,
     socket
     |> assign(:page_title, "Nueva Solicitud de Credito")
     |> assign(:changeset, changeset)
     |> assign(:selected_country, country)
     |> assign(:country_config, Map.get(@country_config, country, @country_config["MX"]))
     |> assign(:submitting, false)
     |> assign(:form, to_form(changeset))}
  end

  def mount(_params, _session, socket) do
    # No country selected, redirect to country selection
    {:ok,
     socket
     |> put_flash(:info, "Selecciona un pais para continuar")
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_event("validate", %{"credit_application" => params}, socket) do
    selected_country = params["country"] || socket.assigns.selected_country

    changeset =
      %CreditApplication{}
      |> CreditApplication.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:selected_country, selected_country)
     |> assign(:country_config, Map.get(@country_config, selected_country, @country_config["MX"]))
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"credit_application" => params}, socket) do
    params =
      if Map.has_key?(params, "country") and String.trim(params["country"]) != "" do
        params
      else
        Map.put(params, "country", socket.assigns.selected_country)
      end

    # Set submitting state
    socket = assign(socket, :submitting, true)

    case Applications.create_application(params) do
      {:ok, application} ->
        {:noreply,
         socket
         |> assign(:submitting, false)
         |> put_flash(:info, "Solicitud creada exitosamente")
         |> push_navigate(to: ~p"/applications/#{application.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:submitting, false)
         |> assign(:changeset, changeset)
         |> assign(:form, to_form(changeset))}

      {:error, reason} when is_binary(reason) ->
        {:noreply,
         socket
         |> assign(:submitting, false)
         |> put_flash(:error, reason)}

      {:error, :unsupported_country} ->
        {:noreply,
         socket
         |> assign(:submitting, false)
         |> put_flash(:error, "Pais no soportado")}

      {:error, reasons} when is_list(reasons) ->
        {:noreply,
         socket
         |> assign(:submitting, false)
         |> put_flash(:error, Enum.join(reasons, ", "))}
    end
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
          <li class="text-base-content/50">Nueva Solicitud</li>
        </ul>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Form -->
        <div class="lg:col-span-2">
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <!-- Country Badge -->
              <div class="flex items-center justify-between mb-2">
                <h2 class="card-title text-lg gap-3">
                  <.icon name="hero-document-plus" class="size-5 text-primary" />
                  Nueva Solicitud de Credito
                </h2>
                <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-base-200">
                  <img src={flag_url(@selected_country)} alt={@selected_country} class="w-6 h-auto rounded-sm" />
                  <span class="text-sm font-medium">{@country_config.name}</span>
                </div>
              </div>

              <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
                <!-- Hidden country field -->
                <input type="hidden" name="credit_application[country]" value={@selected_country} />

                <div class="divider text-xs text-base-content/30 my-2">Informacion Personal</div>

                <!-- Full Name -->
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Nombre Completo</span>
                  </label>
                  <div class="input input-bordered flex items-center gap-2 focus-within:input-primary">
                    <.icon name="hero-user" class="size-4 text-base-content/30" />
                    <input
                      type="text"
                      name="credit_application[full_name]"
                      value={@form[:full_name].value}
                      class="grow bg-transparent outline-none"
                      placeholder="Ingresa tu nombre completo"
                      required
                    />
                  </div>
                  <.field_errors form={@form} field={:full_name} />
                </div>

                <!-- Identity Document -->
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">{@country_config.doc_name}</span>
                    <span class="label-text-alt badge badge-ghost badge-xs">{@selected_country}</span>
                  </label>
                  <div class="input input-bordered flex items-center gap-2 focus-within:input-primary">
                    <.icon name="hero-identification" class="size-4 text-base-content/30" />
                    <input
                      type="text"
                      name="credit_application[identity_document]"
                      value={@form[:identity_document].value}
                      class="grow bg-transparent outline-none font-mono"
                      placeholder={@country_config.doc_placeholder}
                      required
                    />
                  </div>
                  <label class="label">
                    <span class="label-text-alt text-base-content/40">
                      {@country_config.doc_hint}
                    </span>
                  </label>
                  <.field_errors form={@form} field={:identity_document} />
                </div>

                <div class="divider text-xs text-base-content/30 my-2">Informacion Financiera</div>

                <!-- Amounts in grid -->
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <!-- Requested Amount -->
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text font-medium">Monto Solicitado</span>
                    </label>
                    <label class="input input-bordered flex items-center gap-2 focus-within:input-primary">
                      <span class="text-base-content/40 font-mono">$</span>
                      <input
                        type="number"
                        name="credit_application[requested_amount]"
                        value={@form[:requested_amount].value}
                        class="grow bg-transparent outline-none font-mono"
                        placeholder="0.00"
                        step="0.01"
                        min="0"
                        required
                      />
                      <span class="text-xs text-base-content/40 font-medium badge badge-ghost badge-xs">
                        {@country_config.currency}
                      </span>
                    </label>
                    <label class="label">
                      <span class="label-text-alt text-base-content/40">
                        Max: {@country_config.max_amount}
                      </span>
                    </label>
                    <.field_errors form={@form} field={:requested_amount} />
                  </div>

                  <!-- Monthly Income -->
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text font-medium">Ingreso Mensual</span>
                    </label>
                    <label class="input input-bordered flex items-center gap-2 focus-within:input-primary">
                      <span class="text-base-content/40 font-mono">$</span>
                      <input
                        type="number"
                        name="credit_application[monthly_income]"
                        value={@form[:monthly_income].value}
                        class="grow bg-transparent outline-none font-mono"
                        placeholder="0.00"
                        step="0.01"
                        min="0"
                        required
                      />
                      <span class="text-xs text-base-content/40 font-medium badge badge-ghost badge-xs">
                        {@country_config.currency}
                      </span>
                    </label>
                    <.field_errors form={@form} field={:monthly_income} />
                  </div>
                </div>

                <!-- Submit -->
                <div class="card-actions justify-end pt-4 border-t border-base-200">
                  <.link navigate={~p"/applications"} class="btn btn-ghost">
                    Cancelar
                  </.link>
                  <button
                    type="submit"
                    class={["btn btn-primary gap-2", @submitting && "btn-loading"]}
                    disabled={@submitting}
                  >
                    <%= if @submitting do %>
                      <span class="loading loading-spinner loading-xs" />
                      Procesando...
                    <% else %>
                      <.icon name="hero-paper-airplane" class="size-4" />
                      Enviar Solicitud
                    <% end %>
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <!-- Sidebar Info -->
        <div class="space-y-4">
          <!-- Country Rules -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h3 class="font-semibold text-sm flex items-center gap-2">
                <.icon name="hero-shield-check" class="size-4 text-info" />
                Requisitos del Pais
              </h3>
              <div class="mt-3 space-y-2">
                <%= for rule <- @country_config.rules do %>
                  <div class="flex items-start gap-2 text-xs">
                    <.icon name="hero-check-micro" class="size-4 text-success mt-0.5 shrink-0" />
                    <span>{rule}</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Process Info -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h3 class="font-semibold text-sm flex items-center gap-2">
                <.icon name="hero-arrow-path" class="size-4 text-warning" />
                ¿Que sucede despues?
              </h3>
              <ul class="steps steps-vertical text-xs mt-3">
                <li class="step step-primary" data-content="1">Enviar solicitud</li>
                <li class="step" data-content="2">Validacion automatica</li>
                <li class="step" data-content="3">Evaluacion de riesgo</li>
                <li class="step" data-content="4">Decision (aprobado/rechazado)</li>
              </ul>
            </div>
          </div>

          <!-- Security Notice -->
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body p-5">
              <h3 class="font-semibold text-sm flex items-center gap-2">
                <.icon name="hero-lock-closed" class="size-4 text-success" />
                Seguridad
              </h3>
              <div class="mt-3 space-y-2 text-xs text-base-content/60">
                <p>Tu informacion personal (PII) es manejada de forma segura y encriptada.</p>
                <p>Los datos bancarios sensibles nunca son expuestos en la interfaz.</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Back Button at Bottom -->
      <div class="mt-8 flex justify-center">
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm gap-2">
          <.icon name="hero-arrow-left" class="size-4" />
          Volver a seleccion de pais
        </.link>
      </div>
    </div>
    """
  end

  defp flag_url(code) when is_binary(code) do
    "https://flagcdn.com/w40/#{String.downcase(code)}.png"
  end

  defp field_errors(assigns) do
    ~H"""
    <%= if @form[@field].errors != [] do %>
      <%= for {msg, opts} <- @form[@field].errors do %>
        <label class="label">
          <span class="label-text-alt text-error flex items-center gap-1">
            <.icon name="hero-exclamation-circle-micro" class="size-3" />
            {CreditSystemWeb.CoreComponents.translate_error({msg, opts})}
          </span>
        </label>
      <% end %>
    <% end %>
    """
  end
end
