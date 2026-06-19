defmodule RulesBuddyWeb.Layouts do
  use RulesBuddyWeb, :html

  alias RulesBuddy.Users

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="app-shell">
      <header class="header">
        <div class="header-inner">
          <a href={~p"/"} class="header-brand">
            <span class="header-icon">◆</span>
            <span class="header-title">Rules Buddy</span>
          </a>
          <span class="header-tagline">board game rules assistant</span>
        </div>
      </header>

      <.flash_group flash={@flash} />

      <main class="main-content">
        <div class="container">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="flash-group">
      <div :if={msg = Phoenix.Flash.get(@flash, :info)} class="alert alert-info" role="alert">
        {msg}
      </div>
      <div :if={msg = Phoenix.Flash.get(@flash, :error)} class="alert alert-error" role="alert">
        {msg}
      </div>
    </div>
    """
  end

  def current_user(conn_or_assigns) do
    case conn_or_assigns do
      %Plug.Conn{private: %{plug_session: session}} ->
        case session[:user_id] || session["user_id"] do
          nil -> nil
          user_id -> Users.get_user(user_id)
        end

      _ ->
        nil
    end
  end
end
