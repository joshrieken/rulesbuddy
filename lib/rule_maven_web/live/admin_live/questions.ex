defmodule RuleMavenWeb.AdminLive.Questions do
  use RuleMavenWeb, :live_view

  alias RuleMaven.{Games, Users}

  @impl true
  def mount(_params, _session, socket) do
    if Users.game_master?(socket.assigns.current_user) do
      games = Games.list_games()
      questions = Games.admin_list_questions()

      {:ok,
       assign(socket,
         page_title: "Questions",
         questions: questions,
         games: games,
         filter_game_id: nil,
         filter_status: nil,
         search: "",
         confirm_delete_id: nil,
         expanded_id: nil
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied.")
       |> push_navigate(to: ~p"/")}
    end
  end

  defp reload(socket) do
    questions =
      Games.admin_list_questions(
        game_id: socket.assigns.filter_game_id,
        status: socket.assigns.filter_status,
        search: socket.assigns.search
      )

    assign(socket, questions: questions, confirm_delete_id: nil)
  end

  @impl true
  def handle_event("filter", params, socket) do
    game_id =
      case params["game_id"] do
        "" -> nil
        id -> String.to_integer(id)
      end

    status = if params["status"] == "", do: nil, else: params["status"]

    socket =
      socket
      |> assign(filter_game_id: game_id, filter_status: status)
      |> reload()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => q}, socket) do
    {:noreply, socket |> assign(search: q) |> reload()}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(search: "") |> reload()}
  end

  def handle_event("expand", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = if socket.assigns.expanded_id == id, do: nil, else: id
    {:noreply, assign(socket, expanded_id: expanded)}
  end

  def handle_event("delete_question", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirm_delete_id: String.to_integer(id))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete_id: nil)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Enum.find(socket.assigns.questions, &(&1.id == id)) do
      nil -> {:noreply, socket}
      q ->
        Games.delete_question(q)
        {:noreply, reload(socket)}
    end
  end

  def handle_event("set_visibility", %{"id" => id, "visibility" => vis}, socket) do
    id = String.to_integer(id)

    case Enum.find(socket.assigns.questions, &(&1.id == id)) do
      nil -> {:noreply, socket}
      q ->
        Games.update_question_visibility(q, vis)
        {:noreply, reload(socket)}
    end
  end

  defp status_of(q) do
    cond do
      q.answer == "Thinking..." -> :pending
      q.refused -> :refused
      is_binary(q.answer) && String.starts_with?(q.answer, "⚠️") -> :error
      true -> :answered
    end
  end

  defp status_label(:pending), do: {"Pending", "color:var(--accent);background:color-mix(in srgb,var(--accent) 12%,transparent)"}
  defp status_label(:refused), do: {"Refused", "color:var(--text-muted);background:var(--bg-subtle)"}
  defp status_label(:error), do: {"Error", "color:var(--red);background:color-mix(in srgb,var(--red) 10%,transparent)"}
  defp status_label(:answered), do: {"Answered", "color:var(--green);background:color-mix(in srgb,var(--green) 10%,transparent)"}

  @impl true
  def render(assigns) do
    ~H"""
    <div style="max-width:72rem;margin:0 auto;padding:1.25rem 1.5rem">
      <.link navigate={~p"/admin"} class="back-link">&larr; Back to admin</.link>

      <div style="display:flex;align-items:baseline;justify-content:space-between;gap:1rem;margin:0.25rem 0 1rem">
        <h1 style="font-size:1.5rem;font-weight:700">Questions ({length(@questions)})</h1>
      </div>

      <!-- Filters -->
      <form phx-change="filter" phx-submit="filter" style="display:flex;gap:0.5rem;flex-wrap:wrap;margin-bottom:0.75rem;align-items:center">
        <select
          name="game_id"
          style="border:1px solid var(--border);border-radius:0.375rem;padding:0.3rem 0.5rem;font-size:0.8rem;background:var(--bg);color:var(--text)"
        >
          <option value="">All games</option>
          <%= for g <- @games do %>
            <option value={g.id} selected={@filter_game_id == g.id}>{g.name}</option>
          <% end %>
        </select>

        <select
          name="status"
          style="border:1px solid var(--border);border-radius:0.375rem;padding:0.3rem 0.5rem;font-size:0.8rem;background:var(--bg);color:var(--text)"
        >
          <option value="">All statuses</option>
          <option value="answered" selected={@filter_status == "answered"}>Answered</option>
          <option value="pending" selected={@filter_status == "pending"}>Pending</option>
          <option value="refused" selected={@filter_status == "refused"}>Refused</option>
          <option value="error" selected={@filter_status == "error"}>Error</option>
        </select>
      </form>

      <form phx-change="search" phx-submit="search" style="display:flex;gap:0.35rem;margin-bottom:1rem">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search questions / answers…"
          phx-debounce="300"
          style="flex:1;max-width:24rem;border:1px solid var(--border);border-radius:0.375rem;padding:0.3rem 0.6rem;font-size:0.8rem;background:var(--bg);color:var(--text)"
        />
        <%= if @search != "" do %>
          <button type="button" phx-click="clear_search" style="background:none;border:1px solid var(--border);border-radius:0.375rem;padding:0.3rem 0.5rem;font-size:0.75rem;color:var(--text-muted);cursor:pointer">✕ Clear</button>
        <% end %>
      </form>

      <!-- Table -->
      <div style="border:1px solid var(--border);border-radius:0.5rem;overflow:hidden">
        <table style="width:100%;border-collapse:collapse;font-size:0.8rem;table-layout:fixed">
          <colgroup>
            <col style="width:7rem">
            <col style="width:7rem">
            <col style="width:9rem">
            <col>
            <col style="width:5.5rem">
            <col style="width:7rem">
            <col style="width:7rem">
          </colgroup>
          <thead>
            <tr style="background:var(--bg-subtle);text-align:left">
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted);white-space:nowrap">When</th>
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted)">User</th>
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted)">Game</th>
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted)">Question</th>
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted)">Status</th>
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted)">Visibility</th>
              <th style="padding:0.5rem 0.75rem;font-weight:600;color:var(--text-muted)">Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for q <- @questions do %>
              <% status = status_of(q) %>
              <% {label, pill_style} = status_label(status) %>
              <tr style={"border-top:1px solid var(--border-subtle);#{if @expanded_id == q.id, do: "background:var(--bg-subtle)"}"}>
                <td style="padding:0.45rem 0.75rem;white-space:nowrap;color:var(--text-muted);font-size:0.75rem">
                  {Calendar.strftime(q.inserted_at, "%b %-d %H:%M")}
                </td>
                <td style="padding:0.45rem 0.75rem;white-space:nowrap;color:var(--text-secondary);font-size:0.75rem">
                  {q.user && q.user.username || "—"}
                </td>
                <td style="padding:0.45rem 0.75rem;white-space:nowrap;color:var(--text-secondary);font-size:0.75rem">
                  {q.game && q.game.name || "—"}
                </td>
                <td style="padding:0.45rem 0.75rem;overflow:hidden">
                  <button
                    type="button"
                    phx-click="expand"
                    phx-value-id={q.id}
                    style="background:none;border:none;text-align:left;cursor:pointer;padding:0;color:var(--text);font-size:0.8rem;width:100%"
                  >
                    <span style="display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
                      {q.question}
                    </span>
                  </button>
                  <%= if @expanded_id == q.id do %>
                    <div style="margin-top:0.5rem;padding:0.5rem;background:var(--bg);border-radius:0.25rem;border:1px solid var(--border-subtle)">
                      <p style="font-weight:600;font-size:0.75rem;color:var(--text-muted);margin:0 0 0.25rem">Q: {q.question}</p>
                      <p style="font-size:0.78rem;color:var(--text);white-space:pre-wrap;margin:0">{q.answer}</p>
                      <%= if q.cited_passage do %>
                        <p style="margin-top:0.5rem;padding:0.4rem;background:var(--bg-subtle);border-radius:0.2rem;font-size:0.72rem;color:var(--text-muted);font-style:italic">{q.cited_passage}</p>
                      <% end %>
                    </div>
                  <% end %>
                </td>
                <td style="padding:0.45rem 0.75rem;white-space:nowrap">
                  <span style={"font-size:0.65rem;font-weight:600;padding:0.1rem 0.4rem;border-radius:0.25rem;#{pill_style}"}>{label}</span>
                </td>
                <td style="padding:0.45rem 0.75rem;white-space:nowrap">
                  <select
                    phx-change="set_visibility"
                    phx-value-id={q.id}
                    name="visibility"
                    style="border:1px solid var(--border);border-radius:0.25rem;padding:0.1rem 0.25rem;font-size:0.72rem;background:var(--bg);color:var(--text)"
                  >
                    <option value="private" selected={q.visibility == "private"}>Private</option>
                    <option value="public" selected={q.visibility == "public"}>Public</option>
                  </select>
                </td>
                <td style="padding:0.45rem 0.75rem;white-space:nowrap">
                  <%= if @confirm_delete_id == q.id do %>
                    <span style="font-size:0.72rem;color:var(--red);font-weight:600">Delete?</span>
                    <button
                      type="button"
                      phx-click="confirm_delete"
                      phx-value-id={q.id}
                      style="background:none;border:none;color:var(--red);font-size:0.72rem;font-weight:700;cursor:pointer"
                    >Yes</button>
                    <button
                      type="button"
                      phx-click="cancel_delete"
                      style="background:none;border:none;color:var(--text-muted);font-size:0.72rem;cursor:pointer"
                    >No</button>
                  <% else %>
                    <button
                      type="button"
                      phx-click="delete_question"
                      phx-value-id={q.id}
                      style="background:none;border:none;color:var(--text-muted);font-size:0.72rem;cursor:pointer"
                      title="Delete"
                    >✕ Delete</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%= if @questions == [] do %>
          <p style="text-align:center;color:var(--text-muted);font-size:0.8rem;padding:2rem">No questions found.</p>
        <% end %>
      </div>

      <p style="font-size:0.72rem;color:var(--text-muted);margin-top:0.5rem">Showing up to 100 most recent.</p>
    </div>
    """
  end
end
