defmodule Filer.Trainer do
  @moduledoc """
  Train ML models and keep a current model.

  This module provides the API to the trainer.  We generally expect only
  one trainer will be running, and it is generally part of the
  `:filer_index` application.

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

  @doc """
  Start training.

  Does nothing if training is already running.  Training takes a while, so
  runs it as a background task.

  """
  @spec train(GenServer.server()) :: :ok
  def train(trainer \\ {:global, FilerIndex.Trainer}) do
    GenServer.call(trainer, :start)
  end

  @doc """
  Query if a training task is running.

  """
  @spec training?(GenServer.server()) :: boolean()
  def training?(trainer \\ {:global, FilerIndex.Trainer}) do
    GenServer.call(trainer, :training?)
  end

  @doc """
  Get the most recent trainer state.

  Could be `nil` if training has never run, or if no state is yet available on an
  initial run.  If state is available, it is an `t:Axon.Loop.State.t/0` structure.

  """
  @spec trainer_state(GenServer.server()) :: map() | nil
  def trainer_state(trainer \\ {:global, FilerIndex.Trainer}) do
    GenServer.call(trainer, :trainer_state)
  end

  @doc """
  Score some unit of content against a specific model.

  Returns a set of values from the specified model.  Returns an empty list
  if that model does not exist.

  """
  @spec score(GenServer.server(), String.t(), Filer.Files.Content.t()) :: [Filer.Labels.Value.t()]
  def score(trainer \\ {:global, FilerIndex.Trainer}, model_hash, content) do
    GenServer.call(trainer, {:score, model_hash, content})
  end
end
