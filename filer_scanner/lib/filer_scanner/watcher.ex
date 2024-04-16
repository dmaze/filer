defmodule FilerScanner.Watcher do
  @moduledoc """
  Watcher that observes changes in the file system.

  """
  use GenServer
  require Logger
  alias FilerScanner.Api

  @type option() ::
          {:file_system, GenServer.server()}
          | {:task_supervisor, GenServer.server()}
          | {:api, Api.t()}
          | {:path, Path.t()}
  @typep state() :: [option()]

  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {watcher_opts, genserver_opts} =
      Keyword.split(opts, [:file_system, :task_supervisor, :api, :path])

    GenServer.start_link(__MODULE__, watcher_opts, genserver_opts)
  end

  @impl true
  @spec init([option()]) :: {:ok, state()}
  def init(opts) do
    :ok = FileSystem.subscribe(opts[:file_system])

    {:ok, opts}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    # path is an absolute path
    # events is a list of atoms :created :removed :renamed :modified and some others
    Logger.info("Watcher: #{path} #{inspect(events)}")
    filename = path |> String.replace_prefix(state[:path], "") |> String.replace_leading("/", "")

    task =
      Task.Supervisor.async_nolink(state[:task_supervisor], FilerScanner.Scanner, :check, [
        state[:api],
        state[:path],
        filename
      ])

    case Task.yield(task, 100) || Task.ignore(task) do
      {:ok, _reply} ->
        Logger.info("Watcher: #{path} processed")

      {:exit, reason} ->
        Logger.error("Watcher: #{path} exited: #{inspect(reason)}")

      nil ->
        Logger.warning("Watcher: #{path} took more than 100 ms, continuing")
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _watcher_pid, :stop}, state) do
    # We're probably doomed, but we expect our supervisor to restart us.
    {:noreply, state}
  end

  def handle_info({ref, _result}, state) do
    # A task completed
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # A task aborted
    {:noreply, state}
  end
end
