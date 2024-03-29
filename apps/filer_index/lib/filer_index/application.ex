defmodule FilerIndex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    root_dir = Application.fetch_env!(:filer_index, :root_dir)
    oban_config = Application.fetch_env!(:filer_index, Oban)
    :ok = Oban.Telemetry.attach_default_logger()

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
      {FilerIndex.Trainer,
       pubsub: Filer.PubSub, task_supervisor: FilerIndex.TaskSupervisor, name: FilerIndex.Trainer},
      {Oban, oban_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FilerIndex.Supervisor)
  end
end
