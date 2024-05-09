defmodule FilerIndex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    oban_config = Application.fetch_env!(:filer_index, Oban)
    :ok = Oban.Telemetry.attach_default_logger()

    children = [
      {Task.Supervisor, name: FilerIndex.TaskSupervisor},
      {FilerIndex.Trainer,
       pubsub: Filer.PubSub,
       task_supervisor: FilerIndex.TaskSupervisor,
       name: {:global, FilerIndex.Trainer}},
      {Oban, oban_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FilerIndex.Supervisor)
  end
end
