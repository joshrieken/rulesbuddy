defmodule RuleMavenWeb.PageController do
  use RuleMavenWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
