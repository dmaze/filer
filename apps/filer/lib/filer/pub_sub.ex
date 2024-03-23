defmodule Filer.PubSub do
  @moduledoc """
  Application support for the Phoenix publish/subscribe system.

  This module wraps `Phoenix.PubSub`.  There are three groups of functions:
  `topic_...` constructs a topic name for some context; `broadcast_...` sends
  a message; and `subscribe_...` subscribes to some context.

  If a process is subscribed to pub/sub messages, it gets raw messages as
  described in `t:message/0`.

  By default this module assumes that the pub/sub engine runs under
  the module's own name, that is, `Filer.PubSub`.

  """

  @typedoc """
  Messages that may be sent by the publish/subscribe system.

  `:trainer_start`: a model training run has started

  `:trainer_complete`: a model training run has finished, including the
  hash of the model

  `:trainer_failed`: a model training run has failed

  `:trainer_state`: incremental updates on the progress of model training

  """
  @type message() ::
          :trainer_start
          | {:trainer_complete, String.t()}
          | {:trainer_failed, term()}
          | {:trainer_state, Axon.Loop.State.t()}

  # Type-checked wrapper around Phoenix.PubSub.broadcast()
  @spec broadcast(Phoenix.PubSub.t(), Phoenix.PubSub.topic(), message()) :: :ok | {:error, term()}
  defp broadcast(pubsub, topic, message) do
    Phoenix.PubSub.broadcast(pubsub, topic, message)
  end

  # TRAINING EVENTS

  @doc "Name of the single topic for training events."
  @spec topic_trainer() :: String.t()
  def topic_trainer, do: "trainer"

  @doc "Subscribe the current process to training events."
  @spec subscribe_trainer(Phoenix.PubSub.t()) :: :ok | {:error, term()}
  def subscribe_trainer(pubsub \\ __MODULE__) do
    Phoenix.PubSub.subscribe(pubsub, topic_trainer())
  end

  @doc "Send a start-training event."
  @spec broadcast_trainer_start(Phoenix.PubSub.t()) :: :ok | {:error, term()}
  def broadcast_trainer_start(pubsub \\ __MODULE__) do
    broadcast(pubsub, topic_trainer(), :trainer_start)
  end

  @doc "Send a finish-training event."
  @spec broadcast_trainer_complete(Phoenix.PubSub.t(), String.t()) :: :ok | {:error, term()}
  def broadcast_trainer_complete(pubsub \\ __MODULE__, hash) do
    broadcast(pubsub, topic_trainer(), {:trainer_complete, hash})
  end

  @doc "Send a training-failed event."
  @spec broadcast_trainer_failed(Phoenix.PubSub.t(), term()) :: :ok | {:error, term()}
  def broadcast_trainer_failed(pubsub \\ __MODULE__, reason) do
    broadcast(pubsub, topic_trainer(), {:trainer_failed, reason})
  end

  @doc "Send a training-state event."
  @spec broadcast_trainer_state(Phoenix.PubSub.t(), Axon.Loop.State.t()) :: :ok | {:error, term()}
  def broadcast_trainer_state(pubsub \\ __MODULE__, state) do
    broadcast(pubsub, topic_trainer(), {:trainer_state, state})
  end
end
