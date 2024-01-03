defmodule FilerWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      FilerWeb.Telemetry,
      # Start the Endpoint (http/https)
      FilerWeb.Endpoint
      # Start a worker by calling: FilerWeb.Worker.start_link(arg)
      # {FilerWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FilerWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FilerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
