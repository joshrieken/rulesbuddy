defmodule RuleMaven.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RuleMavenWeb.Telemetry,
      RuleMaven.Repo,
      {DNSCluster, query: Application.get_env(:rule_maven, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RuleMaven.PubSub},
      # Start a worker by calling: RuleMaven.Worker.start_link(arg)
      # {RuleMaven.Worker, arg},
      # Start to serve requests, typically the last entry
      RuleMavenWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RuleMaven.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RuleMavenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
