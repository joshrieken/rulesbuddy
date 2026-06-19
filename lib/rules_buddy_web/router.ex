defmodule RulesBuddyWeb.Router do
  use RulesBuddyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RulesBuddyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RulesBuddyWeb.AuthPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RulesBuddyWeb do
    pipe_through :browser

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/logout", AuthController, :logout

    live_session :default, session: {RulesBuddyWeb.UserLiveAuth, :get_session, []} do
      live "/", GameLive.Index, :index
      live "/games/new", GameLive.Form, :new
      live "/games/:id", GameLive.Show, :show
      live "/games/:id/edit", GameLive.Form, :edit
    end
  end
end
