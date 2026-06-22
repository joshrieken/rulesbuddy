defmodule RuleMavenWeb.AdminLive.Users do
  use RuleMavenWeb, :live_view

  alias RuleMaven.Users

  @impl true
  def mount(_params, _session, socket) do
    if Users.game_master?(socket.assigns.current_user) do
      all_users = Users.list_users()
      {:ok, assign(socket, page_title: "Manage Users", users: all_users)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to do that.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("promote_user", %{"id" => id_str}, socket) do
    {id, _} = Integer.parse(id_str)

    case Users.get_user(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "User not found.")}

      user ->
        {:ok, _} = Users.update_user_role(user, "game_master")
        users = Users.list_users()

        {:noreply,
         assign(socket, users: users)
         |> put_flash(:info, "#{user.username} promoted to game master.")}
    end
  end

  def handle_event("demote_user", %{"id" => id_str}, socket) do
    {id, _} = Integer.parse(id_str)

    case Users.get_user(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "User not found.")}

      user ->
        {:ok, _} = Users.update_user_role(user, "player")
        users = Users.list_users()

        {:noreply,
         assign(socket, users: users) |> put_flash(:info, "#{user.username} demoted to player.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="max-width:48rem;margin:0 auto;padding:0.75rem 1rem">
      <.link navigate={~p"/admin"} style="color:var(--blue);font-size:0.75rem">&larr; Back to admin</.link>

      <h1 style="font-size:1.3rem;font-weight:700;margin:0.3rem 0">Manage Users</h1>

      <p style="font-size:0.75rem;color:var(--text-muted);margin:0 0 0.75rem">
        Promote players to game masters, or demote them back. ({length(@users)} users)
      </p>

      <div style="overflow-x:auto;border:1px solid var(--border);border-radius:0.5rem">
        <table style="width:100%;border-collapse:collapse;font-size:0.72rem">
          <thead>
            <tr style="background:var(--bg-subtle);text-align:left">
              <th style="padding:0.3rem 0.5rem;border-bottom:1px solid var(--border)">
                Username
              </th>
              <th style="padding:0.3rem 0.5rem;border-bottom:1px solid var(--border)">Email</th>
              <th style="padding:0.3rem 0.5rem;border-bottom:1px solid var(--border)">Role</th>
              <th style="padding:0.3rem 0.5rem;border-bottom:1px solid var(--border)">Joined</th>
              <th style="padding:0.3rem 0.5rem;border-bottom:1px solid var(--border);width:120px">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for user <- @users do %>
              <tr style="background:var(--bg)">
                <td style="padding:0.25rem 0.5rem;border-bottom:1px solid var(--border-subtle);font-weight:500">
                  {user.username}
                </td>
                <td style="padding:0.25rem 0.5rem;border-bottom:1px solid var(--border-subtle);color:var(--text-muted)">
                  {user.email}
                </td>
                <td style="padding:0.25rem 0.5rem;border-bottom:1px solid var(--border-subtle);font-weight:600">
                  <span style={"#{if user.role == "game_master", do: "color:var(--accent)", else: "color:var(--text-muted)"}"}>
                    {user.role}
                  </span>
                </td>
                <td style="padding:0.25rem 0.5rem;border-bottom:1px solid var(--border-subtle);color:var(--text-muted);font-size:0.65rem">
                  {String.slice(to_string(user.inserted_at), 0, 10)}
                </td>
                <td style="padding:0.15rem 0.5rem;border-bottom:1px solid var(--border-subtle)">
                  <div style="display:flex;gap:0.2rem">
                    <%= if user.role == "player" do %>
                      <button
                        type="button"
                        phx-click="promote_user"
                        phx-value-id={user.id}
                        style="background:none;border:1px solid var(--accent);color:var(--accent);padding:0.15rem 0.35rem;border-radius:0.25rem;font-size:0.6rem;font-weight:600;cursor:pointer"
                      >Promote</button>
                    <% else %>
                      <button
                        type="button"
                        phx-click="demote_user"
                        phx-value-id={user.id}
                        style="background:none;border:1px solid var(--border);color:var(--text-muted);padding:0.15rem 0.35rem;border-radius:0.25rem;font-size:0.6rem;font-weight:600;cursor:pointer"
                      >Demote</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
