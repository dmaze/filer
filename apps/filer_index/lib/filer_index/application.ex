defmodule FilerIndex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    root_dir = Application.fetch_env!(:filer_index, :root_dir)

    children = [
      {Task.Supervisor, name: FilterIndex.TaskSupervisor},
      %{
        id: FileSystem,
        start: {FileSystem, :start_link, [[dirs: [root_dir], name: FilterIndex.FileSystem]]}
      },
      {FilerIndex.Watcher,
       file_system: FilterIndex.FileSystem,
       task_supervisor: FilterIndex.TaskSupervisor,
       root_dir: root_dir,
       name: FilterIndex.Watcher}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FilerIndex.Supervisor)
  end
end
