defmodule FilerIndex.Model do
  @moduledoc """
  Train and run a ML model.

  ### Publish/Subscribe

  As execution progresses, the training sequence will use `Filex.PubSub` to
  publish events.  These events are described in `t:pubsub/0`.  Events are
  always published on the topic `"trainer"`.

  A copy of the most-recent state will be stored in `FilerIndex.Trainer` as
  well.

  If the training sequence fails for whatever reason, this may not broadcast
  the `:trainer_complete` event.  If this is run via `FilerIndex.Trainer`,
  that will observe the failure and broadcast a `:trainer_failed` event.

  """
  import Nx.Defn

  # Fixed image size; 8.5x11 @ 72 dpi.
  @fixed_width 17 * 36
  @fixed_height 11 * 72
  @batch_size 4

  @doc """
  Internal type of the model.

  """
  defstruct [:value_ids, :model, :params]

  @typedoc """
  Internal type of the model.

  `:value_ids` is a simple lookup vector of the database IDs for label values
  used in the model.  `:model` is the actual Axon model, and `:params` is the
  runtime parameters used in training.

  """
  @type t() :: %__MODULE__{value_ids: Nx.t(), model: Axon.t(), params: term()}

  @doc """
  Run the training task, advertising execution and perisiting the result.

  This takes a fairly long time, at least "minutes".  Run it in a Task, an
  Oban worker, or some other asynchronous container.

  This wraps `train/0`.  It sends `Filer.PubSub` events when training starts
  and completes, including on error.  On success, it serializes the result
  to a binary, stores it in `FilerStore`, records a record in the database,
  and includes the model hash in the advertised result.

  Returns the built model, if this is called in a context where that's useful.

  """
  @spec train_and_store(Phoenix.PubSub.t()) :: t()
  def train_and_store(pubsub) do
    :ok = Filer.PubSub.broadcast_trainer_start(pubsub)
    model = train()
    binary = serialize(model)
    hash = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
    :ok = Filer.Store.put({hash, :model}, binary)
    Filer.Models.model_by_hash(hash)
    :ok = Filer.PubSub.broadcast_trainer_complete(pubsub, hash)
    model
  rescue
    e ->
      _ = Filer.PubSub.broadcast_trainer_failed(pubsub, e)
      reraise(e, __STACKTRACE__)
  end

  @doc """
  Get a model by hash from the content store.

  This does not specifically require the hash to be recorded in the database,
  though it generally will be.

  """
  @spec from_store(String.t()) :: {:ok, t()} | :not_found
  def from_store(hash) do
    with {:ok, binary} <- Filer.Store.get({hash, :model}) do
      {:ok, deserialize(binary)}
    end
  end

  @doc """
  Run the training task.

  This takes a fairly long time, at least "minutes".  Run it in a Task or
  another asynchronous container.

  This does the core work of training the model.  This does not on its own
  send updates or store the result, aside from sending
  `Filer.PubSub.broadcast_trainer_state/2` events while training is in
  progress.    Use `train_and_store/0` to get updates and persistence.

  """
  @spec train() :: t()
  def train() do
    # Get all of the manually-labeled content objects.  (This can't be that
    # many of them, and this doesn't include the underlying image data.)
    contents = Filer.Files.list_labeled_contents()

    # Get a tensor of all of the value IDs.
    value_ids =
      contents
      |> Enum.flat_map(& &1.labels)
      |> Enum.map(& &1.id)
      |> MapSet.new()
      |> MapSet.to_list()
      |> Nx.tensor(names: [:label])

    {label_count} = Nx.shape(value_ids)

    datas =
      contents
      |> Stream.chunk_every(@batch_size, @batch_size, :discard)
      |> Stream.map(&batch_data(&1, value_ids))

    batches = div(length(contents), @batch_size)

    # Build the Axon model we're going to train.
    model =
      Axon.input("input", shape: {nil, @fixed_height, @fixed_width, 3})
      |> Axon.conv(32, kernel_size: {8, 8}, activation: :gelu)
      |> Axon.max_pool(kernel_size: {4, 4})
      |> Axon.conv(32, kernel_size: {4, 4}, activation: :gelu)
      |> Axon.max_pool(kernel_size: {4, 4})
      |> Axon.flatten()
      |> Axon.dropout(rate: 0.5)
      |> Axon.dense(label_count, activation: :sigmoid)

    # Train it
    params =
      model
      |> Axon.Loop.trainer(
        :binary_cross_entropy,
        :adamw,
        log: 0
      )
      |> Axon.Loop.metric(:accuracy)
      |> Axon.Loop.metric(:precision)
      |> Axon.Loop.metric(:recall)
      |> Axon.Loop.handle_event(:iteration_completed, &on_iteration_completed/1)
      |> Axon.Loop.run(datas, %{}, epochs: 12, iterations: batches)

    %__MODULE__{value_ids: value_ids, model: model, params: params}
  end

  # Produce data for a batch of contents.
  # Returns a pair of tensors for the input data and expected output.
  @spec batch_data([Filer.Files.Content.t()], Nx.t()) :: {Nx.t(), Nx.t()}
  defp batch_data(contents, value_ids) do
    # Retrieve and lightly preprocess the underlying images.
    # Shape of [document: n, height: 792, width: 612, channel: 3].
    images = contents |> Enum.map(&content_image/1) |> Nx.stack(name: :document)

    # Get a tensor where there is a row per document, and there is a column
    # per label, matching the value_ids.  This is almost a one-hot encoding,
    # except we allow a document to have multiple labels.
    value_ids = Nx.vectorize(value_ids, :value)

    label_vector = fn content ->
      Enum.map(content.labels, & &1.id)
      |> Nx.tensor()
      |> Nx.equal(value_ids)
      |> Nx.sum()
      |> Nx.devectorize()
    end

    # Shape of [document: n, label: w].
    label_matrix = contents |> Enum.map(label_vector) |> Nx.stack(name: :document)

    {images, label_matrix}
  end

  defp on_iteration_completed(state) do
    :ok = Filer.PubSub.broadcast_trainer_state(state)
    metrics = Enum.map_join(state.metrics, ", ", fn {k, v} -> "#{k}: #{Nx.to_number(v)}" end)

    IO.puts(
      "Epoch #{state.epoch}/#{state.max_epoch}, iteration #{state.iteration}/#{state.max_iteration}: #{metrics}"
    )

    {:continue, state}
  end

  @doc """
  Score a single document.

  Returns a list of inferred label values for the document.

  """
  @spec score(Filer.Files.Content.t(), t()) :: [Filer.Labels.Value.t()]
  def score(content, %{value_ids: value_ids, model: model, params: params}) do
    image = content_image(content)
    input = Nx.new_axis(image, 0, :document)

    Axon.predict(model, params, input)
    |> Nx.greater(0.5)
    |> Nx.multiply(value_ids)
    |> Nx.flatten()
    |> Nx.to_list()
    |> Enum.filter(&(&1 > 0))
    |> Enum.map(&Filer.Labels.get_value/1)
  end

  @doc """
  Produce an Nx tensor for a content's image.

  This requires that `FilerStore` contain an object with the content hash of
  type `:png` and variant `:res72`.  This is normally created by the
  `FilerIndex.Workers.Render72` job.  The resulting tensor has a fixed shape
  `{h, w, c}` where `h` is a fixed height, `w` is a fixed width, and `c` is
  3 RGB channels.  In the current implementation, this is exactly 11 inches
  tall and 8.5 inches wide at 72 dpi, with the image being padded or cropped
  to that size if it is different.

  This may be prerendered in the future, if loading a tensor from a binary
  from a file is faster than this transformation.

  """
  @spec content_image(Filer.Files.Content.t()) :: Nx.t()
  def content_image(content) do
    # Take the 72dpi image; flatten it to a single channel; pad and/or crop it
    # to exactly 8.5x11 at 72 dpi.
    {:ok, png} = Filer.Store.get({content.hash, :png, :res72})
    image = StbImage.read_binary!(png) |> StbImage.to_nx()

    # (Note, this post-processing is inappropriate for Nx.Defn, for two
    # reasons: the input isn't a consistent shape, and the dynamic reshaping
    # needs to leave tensor space.)
    {h, w, c} = Nx.shape(image)

    # If there is only a single channel, duplicate it; if there is an alpha channel, drop it.
    image =
      case c do
        1 -> Nx.broadcast(image, {h, w, 3})
        3 -> image
        4 -> Nx.pad(image, 0, [{0, 0, 0}, {0, 0, 0}, {0, -1, 0}])
      end

    # Rescale the image to a range 0-1
    image = rescale(image)

    # Reshape it to a target shape, padding or cropping as needed
    Nx.pad(image, 1.0, [{0, @fixed_height - h, 0}, {0, @fixed_width - w, 0}, {0, 0, 0}])
  end

  defn rescale(t) do
    t = t - Nx.reduce_min(t)
    t / Nx.reduce_max(t)
  end

  @doc """
  Serialize a built model to a binary.

  The binary can be stored in a content store and decoded using
  `deserialize/1`.

  """
  @spec serialize(t()) :: binary()
  def serialize(%{value_ids: value_ids, model: model, params: params}) do
    %{value_ids: Nx.serialize(value_ids), model_and_params: Axon.serialize(model, params)}
    |> :erlang.term_to_binary()
  end

  @doc """
  Reconstruct a serialized model.

  The input must be the result of `serialize/1`, though it may come from
  persisted storage.

  """
  @spec deserialize(binary()) :: t()
  def deserialize(binary) do
    %{value_ids: value_ids, model_and_params: model_and_params} = :erlang.binary_to_term(binary)
    value_ids = Nx.deserialize(value_ids)
    {model, params} = Axon.deserialize(model_and_params)
    %__MODULE__{value_ids: value_ids, model: model, params: params}
  end
end
