defmodule LivePlaygroundWeb.UserLive.Confirmation do
  use LivePlaygroundWeb, :live_view

  alias LivePlayground.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-zinc-100 min-h-screen flex flex-col justify-center sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="text-center text-2xl font-bold text-zinc-900">
          Welcome {@user.email}
        </h2>
      </div>

      <div class="mt-10 mb-20 sm:mx-auto sm:w-full sm:max-w-[480px]">
        <div class="bg-white px-6 py-6 shadow-sm sm:rounded-lg sm:px-12">
          <.simple_form
            :if={!@user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <:actions>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Confirming..."
                class="w-full"
              >
                Confirm and stay logged in
              </.button>
            </:actions>
            <:actions>
              <.button phx-disable-with="Confirming..." class="w-full" kind={:secondary}>
                Confirm and log in only this time
              </.button>
            </:actions>
          </.simple_form>

          <.simple_form
            :if={@user.confirmed_at && @current_scope}
            for={@form}
            id="login_form_sudo"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/users/log-in"}
            phx-trigger-action={@trigger_submit}
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <:actions>
              <.button phx-disable-with="Logging in..." class="w-full">
                Log in
              </.button>
            </:actions>
          </.simple_form>

          <.simple_form
            :if={@user.confirmed_at && !@current_scope}
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/users/log-in"}
            phx-trigger-action={@trigger_submit}
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <:actions>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                class="w-full"
              >
                Keep me logged in on this device
              </.button>
            </:actions>
            <:actions>
              <.button phx-disable-with="Logging in..." class="w-full" kind={:secondary}>
                Log me in only this time
              </.button>
            </:actions>
          </.simple_form>

          <p :if={!@user.confirmed_at} class="mt-6 p-4 bg-amber-50 rounded-md text-sm text-zinc-700">
            <.icon name="hero-light-bulb" class="h-5 w-5 text-amber-500 inline mr-2" />
            Tip: If you prefer passwords, you can enable them in the user settings.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
