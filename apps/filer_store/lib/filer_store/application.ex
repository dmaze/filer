defmodule FilerStore.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    directory = Application.fetch_env!(:filer_store, :directory)

    children = [
      {FilerStore.Server, directory: directory, name: {:global, FilerStore}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FilerStore.Supervisor)
  end
end
