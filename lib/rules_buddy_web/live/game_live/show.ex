defmodule RulesBuddyWeb.GameLive.Show do
  use RulesBuddyWeb, :live_view

  alias RulesBuddy.Games

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, game: nil, question: "", answer: nil, loading: false, recent: [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    game = Games.get_game!(id)
    recent = Games.recent_questions(game)

    {:noreply,
     assign(socket,
       game: game,
       recent: recent,
       question: "",
       answer: nil,
       loading: false
     )}
  end

  @impl true
  def handle_event("ask", %{"question" => question}, socket) do
    question = String.trim(question)

    if question != "" do
      socket = assign(socket, question: question, loading: true, answer: nil)

      send(self(), {:ask_question, question})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:ask_question, question}, socket) do
    %{game: game} = socket.assigns

    case RulesBuddy.LLM.ask(game, question) do
      {:ok, %{answer: answer, cited_passage: passage}} ->
        Games.log_question(%{
          game_id: game.id,
          question: question,
          answer: answer,
          cited_passage: passage
        })

        recent = Games.recent_questions(game)

        {:noreply,
         assign(socket,
           answer: %{answer: answer, cited_passage: passage, question: question},
           recent: recent,
           loading: false
         )}

      {:error, reason} ->
        {:noreply,
         assign(socket,
           answer: %{
             answer: "Sorry, I couldn't get an answer. Error: #{reason}",
             cited_passage: nil,
             question: question
           },
           loading: false
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game-show">
      <div class="mb-4">
        <.link navigate={~p"/"} class="text-blue-600 hover:underline text-sm">
          &larr; Back to games
        </.link>
      </div>

      <h1 class="text-2xl font-bold mb-2">{@game.name}</h1>

      <p class="text-sm text-gray-500 mb-6">
        {length(Games.list_rulebook_sources(@game))} rulebook source(s)
      </p>

      <!-- Question Input -->
      <div class="border rounded-lg p-4 mb-6">
        <form phx-submit="ask" class="flex gap-2">
          <input
            type="text"
            name="question"
            value={@question}
            placeholder="Ask a rules question..."
            class="flex-1 border rounded px-3 py-2"
            disabled={@loading}
          />
          <.button variant="primary" type="submit" disabled={@loading}>
            {if @loading, do: "Asking...", else: "Ask"}
          </.button>
        </form>
      </div>

      <!-- Current Answer -->
      <%= if @answer do %>
        <div class="border rounded-lg p-4 mb-6 bg-gray-50">
          <p class="text-sm text-gray-500 mb-1">Q: {@answer.question}</p>
          <div class="prose prose-sm max-w-none">
            {@answer.answer}
          </div>

          <%= if @answer.cited_passage do %>
            <div class="mt-4 border-l-4 border-blue-500 bg-blue-50 p-3 rounded-r">
              <p class="text-xs font-semibold text-blue-700 mb-1">Cited Passage</p>
              <p class="text-sm text-gray-700 italic">{@answer.cited_passage}</p>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Loading state -->
      <div :if={@loading} class="border rounded-lg p-4 mb-6 bg-gray-50 text-gray-500 animate-pulse">
        Thinking...
      </div>

      <!-- Recent Questions -->
      <%= if @recent != [] do %>
        <div class="mt-8">
          <h2 class="text-lg font-semibold mb-3">Recent Questions</h2>
          <div class="space-y-3">
            <%= for q <- @recent do %>
              <details class="border rounded p-3">
                <summary class="cursor-pointer text-sm font-medium">
                  Q: {q.question}
                </summary>
                <div class="mt-2 text-sm text-gray-700">
                  {q.answer}
                </div>
                <%= if q.cited_passage do %>
                  <div class="mt-2 text-xs text-gray-500 border-l-2 border-blue-300 pl-2">
                    {q.cited_passage}
                  </div>
                <% end %>
              </details>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
