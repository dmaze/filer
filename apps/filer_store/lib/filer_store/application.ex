defmodule FilerStore.Application do
  use Application

  @impl true
  def start(_type, _args) do
    directory = Application.fetch_env!(:filer_store, :directory)

    children = [
      {FilerStore.Server, directory: directory, name: FilerStore}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FilerStore.Supervisor)
  end
end
