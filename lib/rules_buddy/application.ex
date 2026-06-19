defmodule RulesBuddy.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RulesBuddyWeb.Telemetry,
      RulesBuddy.Repo,
      {DNSCluster, query: Application.get_env(:rules_buddy, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RulesBuddy.PubSub},
      # Start a worker by calling: RulesBuddy.Worker.start_link(arg)
      # {RulesBuddy.Worker, arg},
      # Start to serve requests, typically the last entry
      RulesBuddyWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RulesBuddy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RulesBuddyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
