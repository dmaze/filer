defmodule Filer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Discover other nodes
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies), [name: Filer.ClusterSupervisor]]},
      # Start the Ecto repository
      Filer.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Filer.PubSub}
      # Start a worker by calling: Filer.Worker.start_link(arg)
      # {Filer.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Filer.Supervisor)
  end
end
