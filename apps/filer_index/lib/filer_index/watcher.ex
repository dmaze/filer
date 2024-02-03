defmodule FilerIndex.Watcher do
  @moduledoc """
  Watcher that observes changes in the file system.

  """
  use GenServer
  require Logger

  @type option() ::
          {:file_system, GenServer.server()}
          | {:task_supervisor, GenServer.server()}
          | {:file_store, GenServer.server()}
          | {:root_dir, Path.t()}
  @typep state() :: [option()]

  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {watcher_opts, genserver_opts} =
      Keyword.split(opts, [:file_system, :task_supervisor, :file_store, :root_dir])

    GenServer.start_link(__MODULE__, watcher_opts, genserver_opts)
  end

  @impl true
  @spec init([option()]) :: {:ok, state()}
  def init(opts) do
    Logger.info("FilerIndex.Watcher.init/1 #{inspect(opts)}")
    :ok = FileSystem.subscribe(opts[:file_system])

    # Scan all existing files before moving on
    files = Path.wildcard("#{opts[:root_dir]}/**/*.pdf")

    Task.Supervisor.async_stream_nolink(
      opts[:task_supervisor],
      files,
      FilerIndex.Observer,
      :observe,
      [opts[:file_store]],
      ordered: false
    )
    |> Stream.run()

    {:ok, opts}
  end

  @impl true
  def handle_info({:file_event, _watcher_pid, {path, events}}, state) do
    # path is an absolute path
    # events is a list of atoms :created :removed :renamed :modified and some others
    Logger.info("Watcher: #{path} #{inspect(events)}")

    task =
      Task.Supervisor.async_nolink(state[:task_supervisor], FilerIndex.Observer, :observe, [
        path,
        state[:file_store]
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
