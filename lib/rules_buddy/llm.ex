defmodule RulesBuddy.LLM do
  @moduledoc """
  Handles communication with the LLM API via OpenAI-compatible chat completions
  endpoint. Works with Groq, Ollama, Google Gemini (via proxy), and any
  OpenAI-compatible provider.

  Configure via env vars:
    LLM_API_KEY      — default: none (Groq/Ollama don't require one)
    LLM_API_URL      — default: "https://api.groq.com/openai/v1/chat/completions"
    LLM_MODEL        — default: "llama3-70b-8192"
  """

  @default_url "https://api.groq.com/openai/v1/chat/completions"
  @default_model "llama3-70b-8192"

  @doc """
  Asks a rules question about a game and returns the answer with cited passage.
  """
  def ask(game, question) do
    full_text = RulesBuddy.Games.rulebook_text(game)

    system_prompt = build_system_prompt(game.name, full_text)

    body = %{
      model: model(),
      max_tokens: 1024,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: question}
      ]
    }

    headers = [
      {"Authorization", "Bearer #{api_key()}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post(api_url(), json: body, headers: headers) do
      {:ok, %{status: 200, body: response_body}} ->
        parse_response(response_body)

      {:ok, %{status: status, body: body}} ->
        {:error, "API returned status #{status}: #{inspect(body)}"}

      {:error, %{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp build_system_prompt(game_name, full_text) do
    """
    You are a rules assistant for the board game "#{game_name}".

    Below is the full text of the rulebook (and FAQ/errata if provided).
    Answer the user's question using ONLY this text.

    Rules:
    - Always quote or closely paraphrase the specific passage you're basing
      your answer on. Include a reference to where it appears (section/page
      if available).
    - If the rulebook does not clearly address the question, say so plainly
      instead of guessing or inferring an answer. It's better to say "the
      rules don't cover this directly" than to invent a ruling.
    - Be concise. This is being read at a table mid-game.

    RULEBOOK TEXT:
    #{full_text}
    """
  end

  defp parse_response(body) do
    case body do
      %{"choices" => [%{"message" => %{"content" => text}} | _]} ->
        {answer, passage} = extract_passage(text)
        {:ok, %{answer: answer, cited_passage: passage}}

      %{"error" => %{"message" => message}} ->
        {:error, message}

      _ ->
        {:error, "Unexpected API response format"}
    end
  end

  defp extract_passage(text) do
    case String.split(text, ~r{---CITATION---|---PASSAGE---}, parts: 2) do
      [answer, passage] -> {String.trim(answer), String.trim(passage)}
      _ -> {text, nil}
    end
  end

  defp api_url, do: env("LLM_API_URL", @default_url)
  defp model, do: env("LLM_MODEL", @default_model)

  defp api_key do
    env("LLM_API_KEY", "")
  end

  defp env(key, default) do
    Application.get_env(:rules_buddy, String.downcase(key)) || System.get_env(key) || default
  end
end
