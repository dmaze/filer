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

  ### Content events

  New-content events are on a dedicated channel, and include the content
  database ID in the message.

  `:content_new`: a new content record has been inserted

  For other content events, the content database ID is included in both the
  topic and the message.

  `:content_deleted`: a content record has been deleted; also includes
  the content hash

  `:content_labeled`: a content record has been manually labeled

  `:content_inferred`: a content record has new inferred values

  ### Training events

  Normally there should be only one training run at a time.

  `:trainer_start`: a model training run has started

  `:trainer_complete`: a model training run has finished, including the
  hash of the model

  `:trainer_failed`: a model training run has failed

  `:trainer_state`: incremental updates on the progress of model training

  """
  @type message() ::
          {:content_new, integer()}
          | {:content_deleted, integer(), String.t()}
          | {:content_labeled, integer()}
          | {:content_inferred, integer()}
          | :trainer_start
          | {:trainer_complete, String.t()}
          | {:trainer_failed, term()}
          | {:trainer_state, Axon.Loop.State.t()}

  # Type-checked wrapper around Phoenix.PubSub.broadcast()
  @spec broadcast(Phoenix.PubSub.t(), Phoenix.PubSub.topic(), message()) :: :ok | {:error, term()}
  defp broadcast(pubsub, topic, message) do
    Phoenix.PubSub.broadcast(pubsub, topic, message)
  end

  # CONTENT EVENTS

  @doc "Name of the topic for global content updates."
  @spec topic_content_global() :: String.t()
  def topic_content_global(), do: "content"

  @doc "Subscribe the current process to global content events."
  @spec subscribe_content_global(Phoenix.PubSub.t()) :: :ok | {:error, term()}
  def subscribe_content_global(pubsub \\ __MODULE__) do
    Phoenix.PubSub.subscribe(pubsub, topic_content_global())
  end

  @doc "Send a new-content event."
  @spec broadcast_content_new(Phoenix.PubSub.t(), integer()) :: :ok | {:error, term()}
  def broadcast_content_new(pubsub \\ __MODULE__, id) do
    broadcast(pubsub, topic_content_global(), {:content_new, id})
  end

  @doc "Name of the per-content topic for content updates."
  @spec topic_content(integer()) :: String.t()
  def topic_content(id), do: "content:#{id}"

  @doc "Subscribe the current process to content events for a specific content."
  @spec subscribe_content(Phoenix.PubSub.t(), integer()) :: :ok | {:error, term()}
  def subscribe_content(pubsub \\ __MODULE__, id) do
    Phoenix.PubSub.subscribe(pubsub, topic_content(id))
  end

  @doc "Send a content-deleted event."
  @spec broadcast_content_deleted(Phoenix.PubSub.t(), integer(), String.t()) ::
          :ok | {:error, term()}
  def broadcast_content_deleted(pubsub \\ __MODULE__, id, hash) do
    broadcast(pubsub, topic_content(id), {:content_deleted, id, hash})
  end

  @doc "Send a content-labeled event."
  @spec broadcast_content_labeled(Phoenix.PubSub.t(), integer()) :: :ok | {:error, term()}
  def broadcast_content_labeled(pubsub \\ __MODULE__, id) do
    broadcast(pubsub, topic_content(id), {:content_labeled, id})
  end

  @doc "Send a content-inferred event."
  @spec broadcast_content_inferred(Phoenix.PubSub.t(), integer()) :: :ok | {:error, term()}
  def broadcast_content_inferred(pubsub \\ __MODULE__, id) do
    broadcast(pubsub, topic_content(id), {:content_inferred, id})
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
