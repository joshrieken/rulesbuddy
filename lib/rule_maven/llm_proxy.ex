defmodule RuleMaven.LLMProxy do
  @moduledoc """
  Routes LLM traffic through a configured proxy (e.g. Headroom proxy).

  When `LLM_PROXY_URL` env var is set (e.g. `http://localhost:8787`),
  all LLM API calls are rewritten to standard OpenAI-compatible paths
  on the proxy instead of going directly to the provider.

  The proxy is responsible for forwarding to the real upstream.
  Configure the proxy's upstream separately (via Headroom config or
  environment variables on the proxy side).
  """

  @doc "Returns the chat completions URL through the proxy, or nil if proxy is disabled."
  def chat_url do
    if url = proxy_base() do
      Path.join(url, "/v1/chat/completions")
    end
  end

  @doc "Returns the embeddings URL through the proxy, or nil if proxy is disabled."
  def embed_url do
    if url = proxy_base() do
      Path.join(url, "/v1/embeddings")
    end
  end

  @doc "Returns true if proxy is configured."
  def enabled?, do: proxy_base() != nil

  defp proxy_base do
    RuleMaven.Settings.get("llm_proxy_url")
  end
end
