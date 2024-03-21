defmodule FilerIndex.Trainer do
  @moduledoc """
  Train ML models and keep a current model.

  ### Trainer execution and state

  This server ensures at most a single training task is running.  `train/1`
  starts a task, if one is not yet running already; `training?/1` tells if
  it is running or not.

  The trainer keeps some running state.  `trainer_state/1` returns the most
  recent known version of the state.

  If you want to monitor the live state of the trainer, use
  `Filer.PubSub.subscribe_trainer/0` to subscribe to events.  This server
  keeps only the most recent state, and subscribing to pubsub messages will
  be more efficient than polling.

  """
  use GenServer
  require Logger

  @type option() :: {:pubsub, Phoenix.PubSub.t(), :task_supervisor, GenServer.server()}
  @typep state() :: %{
           model: FilerIndex.Model.t() | nil,
           training_task: reference() | nil,
           trainer_state: Axon.Loop.State.t() | nil,
           pubsub: Phoenix.PubSub.t(),
           task_supervisor: GenServer.server()
         }

  @doc """
  Start the trainer as a supervised process.

  Must pass `:pubsub` and `:task_supervisor` as keyword arguments.

  """
  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {trainer_opts, genserver_opts} = Keyword.split(opts, [:pubsub, :task_supervisor])
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
  Get the most recent trainer state.

  Could be `nil` if training has never run, or if no state is yet available on an
  initial run.

  """
  @spec trainer_state(GenServer.server()) :: Axon.Loop.State.t() | nil
  def trainer_state(trainer) do
    GenServer.call(trainer, :trainer_state)
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
    state = %{
      model: nil,
      training_task: nil,
      trainer_state: nil,
      pubsub: opts[:pubsub],
      task_supervisor: opts[:task_supervisor]
    }

    :ok = Filer.PubSub.subscribe_trainer(state.pubsub)
    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), GenServer.from(), state()) :: {:reply, term(), state()}
  def handle_call(request, from, state)

  def handle_call(:start, _, %{training_task: nil, task_supervisor: task_supervisor} = state) do
    task = Task.Supervisor.async_nolink(task_supervisor, FilerIndex.Model, :train, [])
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

  def handle_call(:trainer_state, _, state) do
    {:reply, state.trainer_state, state}
  end

  def handle_call({:score, _}, _, %{model: nil} = state) do
    {:reply, [], state}
  end

  def handle_call({:score, content}, _, %{model: model} = state) do
    {:reply, FilerIndex.Model.score(content, model), state}
  end

  @impl true
  @spec handle_info(term(), state()) :: {:noreply, state()}
  def handle_info(message, state)

  def handle_info({ref, model}, %{training_task: ref} = state) do
    Logger.info("Training task succeeded")
    Process.demonitor(ref, [:flush])
    state = %{state | model: model, training_task: nil}
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{training_task: ref, pubsub: pubsub} = state
      ) do
    Logger.error("Training task failed: #{inspect(reason)}")
    :ok = Filer.PubSub.broadcast_trainer_failed(pubsub, reason)
    state = %{state | training_task: nil}
    {:noreply, state}
  end

  def handle_info(:trainer_start, state), do: {:noreply, state}
  def handle_info(:trainer_complete, state), do: {:noreply, state}
  def handle_info({:trainer_failed, _}, state), do: {:noreply, state}

  def handle_info({:trainer_state, trainer_state}, state) do
    state = %{state | trainer_state: trainer_state}
    {:noreply, state}
  end
end
