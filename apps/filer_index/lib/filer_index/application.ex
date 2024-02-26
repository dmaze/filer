defmodule FilerIndex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    root_dir = Application.fetch_env!(:filer_index, :root_dir)

    children = [
      {Task.Supervisor, name: FilerIndex.TaskSupervisor},
      %{
        id: FileSystem,
        start: {FileSystem, :start_link, [[dirs: [root_dir], name: FilerIndex.FileSystem]]}
      },
      {FilerIndex.Watcher,
       file_system: FilerIndex.FileSystem,
       task_supervisor: FilerIndex.TaskSupervisor,
       file_store: FilerStore,
       root_dir: root_dir,
       name: FilterIndex.Watcher},
      {FilerIndex.Worker, task_supervisor: FilerIndex.TaskSupervisor, filer_store: FilerStore},
      {FilerIndex.Trainer, task_supervisor: FilerIndex.TaskSupervisor, name: FilerIndex.Trainer}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FilerIndex.Supervisor)
  end
end
