defmodule FilerIndex.Worker do
  @moduledoc """
  Background worker to create derived files, feature vectors, &c.

  """
  use GenServer
  require Logger
  alias Filer.Files
  alias Filer.Files.Content

  @type option() :: {:filer_store, GenServer.server()} | {:task_supervisor, GenServer.server()}

  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {worker_opts, genserver_opts} =
      Keyword.split(opts, [:task_supervisor, :filer_store])

    GenServer.start_link(__MODULE__, worker_opts, genserver_opts)
  end

  @typep task() :: {atom(), Content.t()}
  @typep state() :: %{
           filer_store: GenServer.server(),
           task_supervisor: GenServer.server(),
           tasks: [task()],
           current_task: nil | task(),
           task_ref: nil | Task.ref()
         }

  @impl true
  @spec init([option()]) :: {:ok, state(), {:continue, :rescan}}
  def init(opts) do
    state = %{
      filer_store: opts[:filer_store],
      task_supervisor: opts[:task_supervisor],
      tasks: [],
      current_task: nil,
      task_ref: nil
    }

    {:ok, state, {:continue, :rescan}}
  end

  @impl true
  @spec handle_continue(:rescan | :next_task, state()) ::
          {:noreply, state()} | {:noreply, state(), {:continue, :next_task}}
  def handle_continue(:rescan, state) do
    Logger.info("Rescanning all contents for updates")

    tasks =
      Files.list_contents()
      |> Enum.reduce(
        state.tasks,
        &[{FilerIndex.Task.Render72, &1} | &2]
      )

    state = %{state | tasks: tasks}
    {:noreply, state, {:continue, :next_task}}
  end

  def handle_continue(:next_task, %{tasks: [task | tasks], task_ref: nil} = state) do
    {mod, content} = task
    Logger.info("Starting #{inspect(mod)} on content #{content.hash}")

    t =
      Task.Supervisor.async_nolink(state.task_supervisor, mod, :process, [
        content,
        state.filer_store
      ])

    state = %{state | tasks: tasks, current_task: task, task_ref: t.ref}
    {:noreply, state}
  end

  def handle_continue(:next_task, state), do: {:noreply, state}

  @impl true
  def handle_info({ref, _}, %{current_task: task, task_ref: ref} = state) do
    {mod, content} = task
    Logger.info("Successfully finished #{inspect(mod)} on content #{content.hash}")
    Process.demonitor(ref, [:flush])
    state = %{state | current_task: nil, task_ref: nil}
    {:noreply, state, {:continue, :next_task}}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{current_task: task, task_ref: ref} = state
      ) do
    {mod, content} = task

    Logger.error(
      "Failed to #{inspect(mod)} on content #{content.hash} because #{inspect(reason)}"
    )

    state = %{state | current_task: nil, task_ref: nil}
    {:noreply, state, {:continue, :next_task}}
  end
end
