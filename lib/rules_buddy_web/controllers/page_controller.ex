defmodule RulesBuddyWeb.PageController do
  use RulesBuddyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
