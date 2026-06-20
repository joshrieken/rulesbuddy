defmodule RuleMavenWeb.SettingsLive do
  use RuleMavenWeb, :live_view

  alias RuleMaven.Settings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       bgg_api_key: Settings.get("bgg_api_key") || "",
       bgg_user: Settings.get("bgg_user") || "",
       bgg_pass: Settings.get("bgg_pass") || "",
       llm_provider: Settings.get("llm_provider") || "groq",
       llm_key_groq: Settings.get("llm_api_key_groq") || "",
       llm_key_gemini: Settings.get("llm_api_key_gemini") || "",
       llm_model_groq: Settings.get("llm_model_groq") || "llama-3.3-70b-versatile",
       llm_model_gemini: Settings.get("llm_model_gemini") || "gemini-2.5-flash",
       llm_model_ollama: Settings.get("llm_model_ollama") || "mistral",
       saved: false
     )}
  end

  @impl true
  def handle_event("save", params, socket) do
    bgg_api_key = String.trim(params["bgg_api_key"] || "")
    bgg_user = String.trim(params["bgg_user"] || "")
    bgg_pass = String.trim(params["bgg_pass"] || "")
    llm_provider = String.trim(params["llm_provider"] || "groq")
    llm_key_groq = String.trim(params["llm_key_groq"] || "")
    llm_key_gemini = String.trim(params["llm_key_gemini"] || "")
    llm_model_groq = String.trim(params["llm_model_groq"] || "llama3-70b-8192")
    llm_model_gemini = String.trim(params["llm_model_gemini"] || "gemini-2.0-flash")
    llm_model_ollama = String.trim(params["llm_model_ollama"] || "mistral")

    save_setting("bgg_api_key", bgg_api_key)
    save_setting("bgg_user", bgg_user)
    save_setting("bgg_pass", bgg_pass)
    save_setting("llm_provider", llm_provider)
    save_setting("llm_api_key_groq", llm_key_groq)
    save_setting("llm_api_key_gemini", llm_key_gemini)
    save_setting("llm_model_groq", llm_model_groq)
    save_setting("llm_model_gemini", llm_model_gemini)
    save_setting("llm_model_ollama", llm_model_ollama)

    {:noreply,
     assign(socket,
       bgg_api_key: bgg_api_key,
       bgg_user: bgg_user,
       bgg_pass: bgg_pass,
       llm_provider: llm_provider,
       llm_key_groq: llm_key_groq,
       llm_key_gemini: llm_key_gemini,
       llm_model_groq: llm_model_groq,
       llm_model_gemini: llm_model_gemini,
       llm_model_ollama: llm_model_ollama,
       saved: true
     )}
  end

  defp save_setting(key, ""), do: Settings.put(key, nil)
  defp save_setting(key, value), do: Settings.put(key, value)

  @impl true
  def handle_params(_params, _uri, socket) do
    if RuleMaven.Users.game_master?(socket.assigns.current_user) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to do that.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="settings-page">
      <div class="mb-4">
        <.link navigate={~p"/"} class="back-link">
          &larr; Back to games
        </.link>
      </div>

      <h1 class="text-2xl font-bold mb-6">Settings</h1>

      <div :if={@saved} class="alert alert-info mb-4">
        Settings saved.
      </div>

      <div class="border rounded-lg p-4 max-w-lg">
        <form phx-submit="save" class="space-y-4">
          <h2 class="text-sm font-semibold">LLM Provider</h2>

          <div>
            <label for="llm_provider" class="block text-sm font-medium mb-1">
              Provider
            </label>
            <select
              name="llm_provider"
              id="llm_provider"
              class="w-full border rounded px-3 py-2 text-sm"
            >
              <option value="groq" selected={@llm_provider == "groq"}>Groq (free tier)</option>
              <option value="gemini" selected={@llm_provider == "gemini"}>
                Google Gemini (free tier)
              </option>
              <option value="ollama" selected={@llm_provider == "ollama"}>Ollama (local)</option>
            </select>
          </div>

          <div>
            <label for="llm_model_groq" class="block text-sm font-medium mb-1">
              Groq Model
            </label>
            <select
              name="llm_model_groq"
              id="llm_model_groq"
              class="w-full border rounded px-3 py-2 text-sm"
            >
              <option
                value="llama-3.3-70b-versatile"
                selected={@llm_model_groq == "llama-3.3-70b-versatile"}
              >
                llama 3.3 70b (production)
              </option>
              <option
                value="llama-3.1-8b-instant"
                selected={@llm_model_groq == "llama-3.1-8b-instant"}
              >
                llama 3.1 8b (fastest)
              </option>
              <option value="openai/gpt-oss-120b" selected={@llm_model_groq == "openai/gpt-oss-120b"}>
                GPT OSS 120b
              </option>
              <option value="openai/gpt-oss-20b" selected={@llm_model_groq == "openai/gpt-oss-20b"}>
                GPT OSS 20b
              </option>
              <option value="qwen/qwen3-32b" selected={@llm_model_groq == "qwen/qwen3-32b"}>
                Qwen3 32b (preview)
              </option>
              <option
                value="meta-llama/llama-4-scout-17b-16e-instruct"
                selected={@llm_model_groq == "meta-llama/llama-4-scout-17b-16e-instruct"}
              >
                Llama 4 Scout 17b (preview)
              </option>
            </select>
          </div>

          <div>
            <label for="llm_model_gemini" class="block text-sm font-medium mb-1">
              Gemini Model
            </label>
            <select
              name="llm_model_gemini"
              id="llm_model_gemini"
              class="w-full border rounded px-3 py-2 text-sm"
            >
              <option value="gemini-2.5-flash" selected={@llm_model_gemini == "gemini-2.5-flash"}>
                gemini 2.5 flash
              </option>
              <option value="gemini-2.0-flash" selected={@llm_model_gemini == "gemini-2.0-flash"}>
                gemini 2.0 flash
              </option>
              <option
                value="gemini-2.0-flash-lite"
                selected={@llm_model_gemini == "gemini-2.0-flash-lite"}
              >
                gemini 2.0 flash-lite
              </option>
              <option value="gemini-1.5-flash" selected={@llm_model_gemini == "gemini-1.5-flash"}>
                gemini 1.5 flash
              </option>
            </select>
            <p class="text-xs text-gray-400 mt-1">
              Free tier: 2.0 flash + 2.0 flash-lite. Get key at{" "}
              <a
                href="https://aistudio.google.com/apikey"
                target="_blank"
                class="text-blue-500 hover:underline"
              >aistudio.google.com</a>
            </p>
          </div>

          <div>
            <label for="llm_model_ollama" class="block text-sm font-medium mb-1">
              Ollama Model
            </label>
            <select
              name="llm_model_ollama"
              id="llm_model_ollama"
              class="w-full border rounded px-3 py-2 text-sm"
            >
              <option value="mistral" selected={@llm_model_ollama == "mistral"}>mistral (7b)</option>
              <option value="llama3.2" selected={@llm_model_ollama == "llama3.2"}>
                llama3.2 (3b)
              </option>
              <option value="llama3.1:8b" selected={@llm_model_ollama == "llama3.1:8b"}>
                llama3.1 (8b)
              </option>
              <option value="gemma2:9b" selected={@llm_model_ollama == "gemma2:9b"}>
                gemma2 (9b)
              </option>
              <option value="phi3:mini" selected={@llm_model_ollama == "phi3:mini"}>
                phi3 mini (3.8b)
              </option>
            </select>
            <p class="text-xs text-gray-400 mt-1">
              Pull with <code class="text-xs">ollama pull MODEL</code> first.
            </p>
          </div>

          <div>
            <label for="llm_key_groq" class="block text-sm font-medium mb-1">
              Groq API Key
            </label>
            <input
              type="password"
              name="llm_key_groq"
              id="llm_key_groq"
              value={@llm_key_groq}
              placeholder="Groq API key..."
              class="w-full border rounded px-3 py-2"
            />
            <p class="text-xs text-gray-400 mt-1">
              <a href="https://console.groq.com" target="_blank" class="text-blue-500 hover:underline">console.groq.com</a>
            </p>
          </div>

          <div>
            <label for="llm_key_gemini" class="block text-sm font-medium mb-1">
              Gemini API Key
            </label>
            <input
              type="password"
              name="llm_key_gemini"
              id="llm_key_gemini"
              value={@llm_key_gemini}
              placeholder="Gemini API key..."
              class="w-full border rounded px-3 py-2"
            />
            <p class="text-xs text-gray-400 mt-1">
              <a
                href="https://aistudio.google.com"
                target="_blank"
                class="text-blue-500 hover:underline"
              >aistudio.google.com</a>
            </p>
          </div>

          <hr class="my-4" />
          <div>
            <label for="bgg_api_key" class="block text-sm font-medium mb-1">
              BGG API Token
            </label>
            <input
              type="password"
              name="bgg_api_key"
              id="bgg_api_key"
              value={@bgg_api_key}
              placeholder="Bearer token from boardgamegeek.com/applications..."
              class="w-full border rounded px-3 py-2"
            />
            <p class="text-xs text-gray-400 mt-1">
              Register at boardgamegeek.com/applications to get a token.
              Sent as Authorization: Bearer header on all BGG API requests.
            </p>
          </div>

          <div>
            <h3 class="text-sm font-semibold mt-6 mb-2">BGG Login Credentials</h3>
            <p class="text-xs text-gray-400 mb-3">
              Needed to download rulebook PDFs from BGG. Optional — only for
              private collections and file downloads.
            </p>
          </div>

          <div>
            <label for="bgg_user" class="block text-sm font-medium mb-1">
              BGG Username
            </label>
            <input
              type="text"
              name="bgg_user"
              id="bgg_user"
              value={@bgg_user}
              placeholder="BGG login username..."
              class="w-full border rounded px-3 py-2"
            />
          </div>

          <div>
            <label for="bgg_pass" class="block text-sm font-medium mb-1">
              BGG Password
            </label>
            <input
              type="password"
              name="bgg_pass"
              id="bgg_pass"
              value={@bgg_pass}
              placeholder="BGG login password..."
              class="w-full border rounded px-3 py-2"
            />
            <p class="text-xs text-gray-400 mt-1">
              Stored locally in your database. Never shared.
            </p>
          </div>

          <button
            type="submit"
            class="btn btn-primary"
            style="background:var(--accent);color:white;border:none;padding:0.5rem 1.5rem;border-radius:0.375rem;font-weight:600;cursor:pointer"
          >
            Save
          </button>
        </form>
      </div>
    </div>
    """
  end
end
