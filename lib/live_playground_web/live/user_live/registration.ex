defmodule LivePlaygroundWeb.UserLive.Registration do
  use LivePlaygroundWeb, :live_view

  alias LivePlayground.Accounts
  alias LivePlayground.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-zinc-100 min-h-screen flex flex-col justify-center sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="text-center text-2xl font-bold text-zinc-900">
          Create your account
        </h2>
        <p class="mt-2 text-center text-sm text-zinc-600">
          Already have an account?
          <.link navigate={~p"/users/log-in"} class="font-semibold">
            Sign in
          </.link>
        </p>
      </div>

      <div class="mt-10 mb-20 sm:mx-auto sm:w-full sm:max-w-[480px]">
        <div class="bg-white px-6 py-6 shadow-sm sm:rounded-lg sm:px-12">
          <.simple_form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
            <.input
              field={@form[:email]}
              type="email"
              label="Email address"
              autocomplete="email"
              required
              phx-mounted={JS.focus()}
            />

            <:actions>
              <.button phx-disable-with="Creating account..." class="w-full">
                Create account
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: LivePlaygroundWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
