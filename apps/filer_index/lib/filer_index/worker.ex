defmodule FilerIndex.Worker do
  @moduledoc """
  Background worker to create derived files, feature vectors, &c.

  """
  use GenServer
  require Logger
  alias Filer.Files
  alias Filer.Files.Content

  @type option() ::
          {:filer_store, GenServer.server()}
          | {:ml, GenServer.server()}
          | {:pubsub, Phoenix.PubSub.t()}
          | {:task_supervisor, GenServer.server()}

  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {worker_opts, genserver_opts} =
      Keyword.split(opts, [:filer_store, :ml, :pubsub, :task_supervisor])

    GenServer.start_link(__MODULE__, worker_opts, genserver_opts)
  end

  @typep task() :: {atom(), atom(), [term()], Content.t()}
  @typep state() :: %{
           filer_store: GenServer.server(),
           task_supervisor: GenServer.server(),
           ml: GenServer.server(),
           pubsub: Phoenix.PubSub.t(),
           tasks: [task()],
           current_task: nil | task(),
           task_ref: nil | Task.ref()
         }

  @impl true
  @spec init([option()]) :: {:ok, state(), {:continue, :rescan}}
  def init(opts) do
    state = %{
      filer_store: opts[:filer_store],
      ml: opts[:ml],
      pubsub: opts[:pubsub],
      task_supervisor: opts[:task_supervisor],
      tasks: [],
      current_task: nil,
      task_ref: nil
    }

    :ok = Phoenix.PubSub.subscribe(state.pubsub, "trainer")

    {:ok, state, {:continue, :rescan}}
  end

  @impl true
  @spec handle_continue(:rescan | :next_task, state()) ::
          {:noreply, state()} | {:noreply, state(), {:continue, :next_task}}
  def handle_continue(:rescan, state) do
    Logger.info("Rescanning all contents for updates")

    state =
      state
      |> create_content_tasks(&{FilerIndex.Task.Render72, :process, [&1, state.filer_store], &1})

    {:noreply, state, {:continue, :next_task}}
  end

  def handle_continue(:next_task, %{tasks: [task | tasks], task_ref: nil} = state) do
    {mod, func, args, _content} = task
    # Logger.info("Starting #{inspect(mod)} on content #{content.hash}")
    t = Task.Supervisor.async_nolink(state.task_supervisor, mod, func, args)
    state = %{state | tasks: tasks, current_task: task, task_ref: t.ref}
    {:noreply, state}
  end

  def handle_continue(:next_task, state) do
    Logger.info("All tasks finished")
    {:noreply, state}
  end

  @impl true
  def handle_info({ref, _}, %{task_ref: ref} = state) do
    # {mod, _, _, content} = state.current_task
    # Logger.info("Successfully finished #{inspect(mod)} on content #{content.hash}")
    Process.demonitor(ref, [:flush])
    state = %{state | current_task: nil, task_ref: nil}
    {:noreply, state, {:continue, :next_task}}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{current_task: task, task_ref: ref} = state
      ) do
    {mod, _, _, content} = task

    Logger.error(
      "Failed to #{inspect(mod)} on content #{content.hash} because #{inspect(reason)}"
    )

    state = %{state | current_task: nil, task_ref: nil}
    {:noreply, state, {:continue, :next_task}}
  end

  def handle_info(:trainer_start, state), do: {:noreply, state}
  def handle_info({:trainer_state, _}, state), do: {:noreply, state}
  def handle_info({:trainer_failed, _}, state), do: {:noreply, state}

  def handle_info(:trainer_complete, state) do
    Logger.info("Rescoring all contents")
    state = state |> create_content_tasks(&{FilerIndex.Task.Score, :process, [&1, state.ml], &1})
    {:noreply, state, {:continue, :next_task}}
  end

  # Create a batch of tasks for all of the content objects.
  # Takes the old state and returns the new state.
  # The provided builder function takes a Content object and returns a
  # {module, function, args} tuple.
  @spec create_content_tasks(state(), (Content.t() -> task())) :: state()
  defp create_content_tasks(state, builder) do
    tasks = Files.list_contents() |> Enum.reduce(state.tasks, &[builder.(&1) | &2])
    %{state | tasks: tasks}
  end
end
