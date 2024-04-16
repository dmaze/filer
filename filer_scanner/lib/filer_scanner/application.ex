defmodule FilerScanner.Application do
  @moduledoc """
  Main application definition for the scanner.

  """
  use Application

  @impl Application
  def start(_type, _args) do
    url = Application.fetch_env!(:filer_scanner, :url)
    path = Application.fetch_env!(:filer_scanner, :path)
    continuous = Application.fetch_env!(:filer_scanner, :continuous) in ["yes", "true", "1"]

    api = FilerScanner.Api.new(url)

    children = [
      Supervisor.child_spec({FilerScanner.Pruner, api: api, path: path}, significant: true),
      Supervisor.child_spec({FilerScanner.Scanner, api: api, path: path}, significant: true)
    ]

    if continuous do
      children =
        children ++
          [
            {Task.Supervisor, name: FilerScanner.TaskSupervisor},
            {FileSystem.Worker, dirs: [path], name: FilerScanner.FileSystem},
            {FilerScanner.Watcher,
             task_supervisor: FilerScanner.TaskSupervisor,
             api: api,
             path: path,
             name: FilerScanner.Watcher}
          ]

      Supervisor.start_link(children, strategy: :one_for_one, name: FilerScanner.Supervisor)
    else
      Supervisor.start_link(children,
        strategy: :one_for_one,
        auto_shutdown: :all_significant,
        name: FilerScanner.Supervisor
      )
    end
  end
end
