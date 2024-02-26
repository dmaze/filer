defmodule FilerIndex.Ml do
  @moduledoc """
  Train and run a ML model.

  """
  import Nx.Defn

  # Fixed image size; 8.5x11 @ 72 dpi.
  @fixed_width 17 * 36
  @fixed_height 11 * 72

  def train() do
    contents = Filer.Files.list_labeled_contents()

    # Retrieve and lightly preprocess the underlying images.
    # Shape of [document: n, height: 792, width: 612, channel: 3].
    images = contents |> Enum.map(&content_image/1) |> Nx.stack(name: :document)

    # Get a tensor of all of the value IDs.
    value_ids =
      contents
      |> Enum.flat_map(& &1.labels)
      |> Enum.map(& &1.id)
      |> MapSet.new()
      |> MapSet.to_list()
      |> Nx.tensor(names: [:label])

    {label_count} = Nx.shape(value_ids)

    # Get a tensor where there is a row per document, and there is a column
    # per label, matching the value_ids.  This is almost a one-hot encoding,
    # except we allow a document to have multiple labels.
    label_vector = fn content ->
      Enum.map(content.labels, & &1.id)
      |> Nx.tensor()
      |> Nx.new_axis(0)
      |> Nx.equal(value_ids)
      |> Nx.sum(axes: [0])
    end

    # Shape of [document: n, label: w].
    label_matrix = contents |> Enum.map(label_vector) |> Nx.stack(name: :document)

    # Build the Axon model we're going to train.
    model =
      Axon.input("input", shape: {nil, @fixed_height, @fixed_width, 3})
      |> Axon.conv(32, kernel_size: {8, 8}, activation: :gelu)
      |> Axon.max_pool(kernel_size: {4, 4})
      |> Axon.conv(32, kernel_size: {4, 4}, activation: :gelu)
      |> Axon.max_pool(kernel_size: {4, 4})
      |> Axon.flatten()
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
      |> Axon.Loop.handle_event(:epoch_completed, &on_epoch_completed/1)
      |> Axon.Loop.run([{images, label_matrix}], %{}, epochs: 20)

    %{value_ids: value_ids, model: model, params: params}
  end

  defp on_epoch_completed(state) do
    metrics = Enum.map_join(state.metrics, ", ", fn {k, v} -> "#{k}: #{Nx.to_number(v)}" end)

    IO.puts("Epoch #{state.epoch}/#{state.max_epoch}: #{metrics}")

    {:continue, state}
  end

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

  def content_image(content) do
    # We might consider prerendering this.
    #
    # Take the 72dpi image; flatten it to a single channel; pad and/or crop it
    # to exactly 8.5x11 at 72 dpi.
    {:ok, png} = FilerStore.get(FilerStore, {content.hash, :png, :res72})
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
end
