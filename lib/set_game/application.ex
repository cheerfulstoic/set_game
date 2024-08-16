defmodule SetGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SetGameWeb.Telemetry,
      SetGame.Repo,
      {DNSCluster, query: Application.get_env(:set_game, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SetGame.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SetGame.Finch},
      # Start a worker by calling: SetGame.Worker.start_link(arg)
      # {SetGame.Worker, arg},
      # Start to serve requests, typically the last entry
      SetGameWeb.Endpoint,
      SetGame.Game.PlayersRegistry
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SetGame.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SetGameWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
