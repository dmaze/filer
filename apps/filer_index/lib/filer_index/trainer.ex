defmodule FilerIndex.Trainer do
  @moduledoc """
  Train ML models and keep a current model.

  """
  use GenServer
  require Logger

  @type option() :: {:task_supervisor, GenServer.server()}
  @typep state() :: %{
          ml: FilerIndex.Ml.t() | nil,
          training_task: reference() | nil,
          task_supervisor: GenServer.server()
        }

  @doc """
  Start the trainer as a supervised process.

  Must pass `task_supervisor` as a keyword argument.

  """
  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {trainer_opts, genserver_opts} = Keyword.split(opts, [:task_supervisor])
    GenServer.start_link(__MODULE__, trainer_opts, genserver_opts)
  end

  @doc """
  Start training.

  Does nothing if training is already running.  Training takes a while, so
  runs it as a background task.

  """
  @spec train(GenServer.server()) :: :ok
  def train(trainer) do
    GenServer.call(trainer, :start)
  end

  @doc """
  Query if a training task is running.

  """
  @spec training?(GenServer.server()) :: boolean()
  def training?(trainer) do
    GenServer.call(trainer, :training?)
  end

  @doc """
  Score some unit of content.

  Returns a set of values from the most recently completed training run.
  Returns an empty list if training has never run.

  """
  @spec score(GenServer.server(), Filer.Files.Content.t()) :: [Filer.Labels.Value.t()]
  def score(trainer, content) do
    GenServer.call(trainer, {:score, content})
  end

  @impl true
  @spec init([option()]) :: {:ok, state()}
  def init(opts) do
    state = %{ml: nil, training_task: nil, task_supervisor: opts[:task_supervisor]}
    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), GenServer.from(), state()) :: {:reply, term(), state()}
  def handle_call(request, from, state)

  def handle_call(:start, _, %{training_task: nil, task_supervisor: task_supervisor} = state) do
    task = Task.Supervisor.async_nolink(task_supervisor, FilerIndex.Ml, :train, [])
    state = %{state | training_task: task.ref}
    {:reply, :ok, state}
  end

  def handle_call(:start, _, state) do
    # ignore the request
    {:reply, :ok, state}
  end

  def handle_call(:training?, _, %{training_task: training_task} = state) do
    {:reply, training_task != nil, state}
  end

  def handle_call({:score, _}, _, %{ml: nil} = state) do
    {:reply, [], state}
  end

  def handle_call({:score, content}, _, %{ml: ml} = state) do
    {:reply, FilerIndex.Ml.score(content, ml), state}
  end

  @impl true
  @spec handle_info(term(), state()) :: {:noreply, state()}
  def handle_info(message, state)

  def handle_info({ref, ml}, %{training_task: ref} = state) do
    Logger.info("Training task succeeded")
    Process.demonitor(ref, [:flush])
    state = %{state | ml: ml, training_task: nil}
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{training_task: ref} = state) do
    Logger.error("Training task failed: #{inspect(reason)}")
    state = %{state | training_task: nil}
    {:noreply, state}
  end
end
