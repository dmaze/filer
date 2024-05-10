defmodule FilerIndex.Trainer do
  @moduledoc """
  Train ML models and keep a current model.

  This module is the `GenServer` implementation of `Filer.Trainer`, and it
  is usually accessible via `{:global, FilerIndex.Trainer}`.


  """
  alias FilerIndex.Model
  use GenServer
  require Logger

  @type option() :: {:pubsub, Phoenix.PubSub.t(), :task_supervisor, GenServer.server()}
  @typep state() :: %{
           models: %{String.t() => Model.t()},
           training_task: reference() | nil,
           trainer_state: Filer.PubSub.trainer_state() | nil,
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

  @impl true
  @spec init([option()]) :: {:ok, state()}
  def init(opts) do
    state = %{
      models: %{},
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

  def handle_call(
        :start,
        _,
        %{training_task: nil, task_supervisor: task_supervisor, pubsub: pubsub} = state
      ) do
    task =
      Task.Supervisor.async_nolink(task_supervisor, FilerIndex.Model, :train_and_store, [pubsub])

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

  def handle_call({:score, model_hash, content}, _, state) do
    {maybe_model, state} = get_model(state, model_hash)
    values = case maybe_model do
        nil -> []
        model -> FilerIndex.Model.score(content, model)
      end

    {:reply, values, state}
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
        %{training_task: ref} = state
      ) do
    Logger.error("Training task failed: #{inspect(reason)}")
    state = %{state | training_task: nil}
    {:noreply, state}
  end

  def handle_info(:trainer_start, state), do: {:noreply, state}
  def handle_info({:trainer_complete, _}, state), do: {:noreply, state}
  def handle_info({:trainer_failed, _}, state), do: {:noreply, state}

  def handle_info({:trainer_state, trainer_state}, state) do
    state = %{state | trainer_state: trainer_state}
    {:noreply, state}
  end

  # Get a specific model by hash, caching it.
  @spec get_model(state(), String.t()) :: {Model.t() | nil, state()}
  defp get_model(state, hash) do
    models =
      state.models
      |> Map.put_new_lazy(hash, fn ->
        case Model.from_store(hash) do
          :not_found -> nil
          {:ok, model} -> model
        end
      end)

    case Map.get(models, hash) do
      nil -> {nil, state}
      model -> {model, %{state | models: models}}
    end
  end
end
