defmodule RuleMavenWeb.MetricsController do
  use RuleMavenWeb, :controller

  alias RuleMaven.Metrics

  @doc """
  Records a theme selection. Fired from the theme picker in the root layout.
  Always responds 204 — the client doesn't care about the result, and an
  invalid/garbage theme is simply dropped by the context.
  """
  def theme(conn, %{"theme" => theme}) do
    user_id = conn.assigns[:current_user] && conn.assigns.current_user.id
    Metrics.record_theme(theme, user_id)
    send_resp(conn, :no_content, "")
  end

  def theme(conn, _params), do: send_resp(conn, :no_content, "")
end
