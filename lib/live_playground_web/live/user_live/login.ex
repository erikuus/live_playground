defmodule LivePlaygroundWeb.UserLive.Login do
  use LivePlaygroundWeb, :live_view

  alias LivePlayground.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-zinc-100 min-h-screen flex flex-col justify-center sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="text-center text-2xl font-bold text-zinc-900">
          Sign in to your account
        </h2>
        <p class="mt-2 text-center text-sm text-zinc-600">
          <%= if @current_scope do %>
            You need to reauthenticate to perform sensitive actions on your account.
          <% else %>
            Don't have an account?
            <.link navigate={~p"/users/register"} class="font-semibold">
              Sign up
            </.link>
          <% end %>
        </p>
      </div>

      <div class="mt-10 mb-20 sm:mx-auto sm:w-full sm:max-w-[480px]">
        <div class="bg-white px-6 py-6 shadow-sm sm:rounded-lg sm:px-12">
          <div :if={local_mail_adapter?()} class="mb-6 p-4 bg-blue-50 rounded-md">
            <div class="flex">
              <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400" />
              <div class="ml-3 text-sm text-blue-700">
                <p>You are running the local mail adapter.</p>
                <p>
                  To see sent emails, visit <.link href="/dev/mailbox" class="underline font-medium">the mailbox page</.link>.
                </p>
              </div>
            </div>
          </div>

          <.simple_form
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
          >
            <.input
              readonly={!!@current_scope}
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />
            <:actions>
              <.button class="w-full">
                Log in with email <span aria-hidden="true">→</span>
              </.button>
            </:actions>
          </.simple_form>

          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-zinc-300"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="bg-white px-2 text-zinc-500">or</span>
            </div>
          </div>

          <.simple_form
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              readonly={!!@current_scope}
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="email"
              required
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
            />
            <:actions>
              <.button class="w-full" name={@form[:remember_me].name} value="true">
                Log in and stay logged in <span aria-hidden="true">→</span>
              </.button>
            </:actions>
            <:actions>
              <.button class="w-full" kind={:secondary}>
                Log in only this time
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:live_playground, LivePlayground.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
