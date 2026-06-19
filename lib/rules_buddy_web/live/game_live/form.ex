defmodule RulesBuddyWeb.GameLive.Form do
  use RulesBuddyWeb, :live_view

  alias RulesBuddy.Games

  @max_pdfs 10

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        game: nil,
        source_entries: [%{id: 0, label: "", text: ""}],
        game_changeset: nil
      )
      |> allow_upload(:rulebook_pdfs,
        accept: ["application/pdf"],
        max_entries: @max_pdfs,
        max_file_size: 50_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if RulesBuddy.Users.game_master?(socket.assigns.current_user) do
      do_handle_params(params, socket)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to do that.")
       |> push_navigate(to: ~p"/")}
    end
  end

  defp do_handle_params(params, socket) do
    socket =
      case params do
        %{"id" => id} ->
          game = Games.get_game!(id)

          sources =
            game
            |> Games.list_rulebook_sources()
            |> Enum.with_index()
            |> Enum.map(fn {s, i} -> %{id: i, label: s.label, text: s.full_text} end)

          entries = if sources == [], do: [%{id: 0, label: "", text: ""}], else: sources

          assign(socket,
            game: game,
            source_entries: entries,
            game_changeset: Games.change_game(game)
          )

        _ ->
          changeset = Games.change_game(%Games.Game{})

          assign(socket,
            game: nil,
            source_entries: [%{id: 0, label: "", text: ""}],
            game_changeset: changeset
          )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_source", _params, socket) do
    entries = socket.assigns.source_entries
    next_id = (Enum.map(entries, & &1.id) ++ [-1]) |> Enum.max() |> Kernel.+(1)
    {:noreply, assign(socket, source_entries: entries ++ [%{id: next_id, label: "", text: ""}])}
  end

  @impl true
  def handle_event("remove_source", %{"id" => id}, socket) do
    id = String.to_integer(id)
    entries = Enum.reject(socket.assigns.source_entries, &(&1.id == id))
    entries = if entries == [], do: [%{id: 0, label: "", text: ""}], else: entries
    {:noreply, assign(socket, source_entries: entries)}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save", %{"game" => game_params} = all_params, socket) do
    source_map =
      socket.assigns.source_entries
      |> Enum.map(fn entry ->
        label = all_params["label_#{entry.id}"] || ""
        text = all_params["text_#{entry.id}"] || ""
        {label, text}
      end)
      |> Enum.filter(fn {l, t} -> String.trim(l) != "" && String.trim(t) != "" end)
      |> Map.new()

    pdf_texts =
      consume_uploaded_entries(socket, :rulebook_pdfs, fn %{path: path}, entry ->
        case extract_pdf_text(path) do
          {:ok, text} ->
            label =
              entry.client_name
              |> Path.rootname()
              |> String.replace(~r/[_\-]/, " ")

            {:ok, {label, text}}

          {:error, reason} ->
            {:ok, {entry.client_name, "Error extracting text: #{reason}"}}
        end
      end)

    merged =
      Enum.reduce(pdf_texts, source_map, fn {label, text}, acc ->
        Map.put_new(acc, label, text)
      end)

    save_game(socket, socket.assigns.game, game_params, merged)
  end

  defp extract_pdf_text(path) do
    case System.cmd("pdftotext", ["-nopgbrk", path, "-"]) do
      {text, 0} ->
        if String.trim(text) == "" do
          {:error, "PDF contains no extractable text (may be scanned)"}
        else
          {:ok, text}
        end

      {_output, exit_code} ->
        {:error, "pdftotext failed (exit #{exit_code})"}
    end
  rescue
    e ->
      {:error, "pdftotext error: #{Exception.message(e)}"}
  end

  defp save_game(socket, nil, game_params, source_map) do
    case Games.create_game(game_params) do
      {:ok, game} ->
        Enum.each(source_map, fn {label, text} ->
          Games.create_rulebook_source(%{game_id: game.id, label: label, full_text: text})
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Game created!")
         |> push_navigate(to: ~p"/games/#{game.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, game_changeset: changeset)}
    end
  end

  defp save_game(socket, game, game_params, source_map) do
    case Games.update_game(game, game_params) do
      {:ok, game} ->
        existing = Games.list_rulebook_sources(game)

        existing
        |> Enum.filter(fn s -> not Map.has_key?(source_map, s.label) end)
        |> Enum.each(&Games.delete_rulebook_source/1)

        existing_labels = MapSet.new(existing, & &1.label)

        source_map
        |> Enum.filter(fn {label, _} -> not MapSet.member?(existing_labels, label) end)
        |> Enum.each(fn {label, text} ->
          Games.create_rulebook_source(%{game_id: game.id, label: label, full_text: text})
        end)

        {:noreply,
         socket
         |> put_flash(:info, "Game updated!")
         |> push_navigate(to: ~p"/games/#{game.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, game_changeset: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game-form">
      <h1 class="text-2xl font-bold mb-6">
        {if @game, do: "Edit #{@game.name}", else: "Add Game"}
      </h1>

      <.form
        for={@game_changeset}
        id="game-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <div>
          <label for="game_name" class="block text-sm font-medium mb-1">Game Name</label>
          <input
            type="text"
            name="game[name]"
            id="game_name"
            value={@game_changeset.data.name}
            class="w-full border rounded px-3 py-2"
            required
          />
        </div>

        <div>
          <label for="game_bgg_id" class="block text-sm font-medium mb-1">
            BGG ID <span class="text-gray-400">(optional)</span>
          </label>
          <input
            type="number"
            name="game[bgg_id]"
            id="game_bgg_id"
            value={@game_changeset.data.bgg_id}
            class="w-full border rounded px-3 py-2"
          />
        </div>

        <div class="space-y-4">
          <h2 class="text-lg font-semibold">Rulebook Sources</h2>

          <%= for entry <- @source_entries do %>
            <div class="border rounded p-4">
              <div class="flex gap-2 items-start">
                <div class="flex-1">
                  <label class="block text-sm font-medium mb-1">Label</label>
                  <input
                    type="text"
                    name={"label_#{entry.id}"}
                    value={entry.label}
                    placeholder="e.g. Core Rulebook"
                    class="w-full border rounded px-3 py-2"
                  />
                </div>
                <div class="flex-1">
                  <label class="block text-sm font-medium mb-1">Text</label>
                  <textarea
                    name={"text_#{entry.id}"}
                    rows="8"
                    class="w-full border rounded px-3 py-2 font-mono text-xs"
                    placeholder="Paste rulebook text here..."
                  ><%= entry.text %></textarea>
                </div>
                <button
                  :if={length(@source_entries) > 1}
                  type="button"
                  phx-click="remove_source"
                  phx-value-id={entry.id}
                  class="btn-remove-source"
                >
                  ✕
                </button>
              </div>
            </div>
          <% end %>

          <button
            type="button"
            phx-click="add_source"
            class="btn-add-source"
          >
            + Add another source
          </button>
        </div>

        <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center">
          <label class="block text-sm font-medium mb-2">Or upload PDF rulebooks</label>
          <.live_file_input upload={@uploads.rulebook_pdfs} class="block mx-auto text-sm" />
          <%= for entry <- @uploads.rulebook_pdfs.entries do %>
            <p class="text-xs text-gray-500 mt-1">{entry.client_name} ({entry.progress}%)</p>
          <% end %>
        </div>

        <div class="flex gap-3">
          <.button variant="primary" type="submit">Save</.button>
          <.button variant="secondary" navigate={~p"/"}>Cancel</.button>
        </div>
      </.form>
    </div>
    """
  end
end
