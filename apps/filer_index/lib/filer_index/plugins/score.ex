defmodule FilerIndex.Plugins.Score do
  @moduledoc """
  Oban plugin to score documents.

  This observes the results of training, and generates jobs to score
  documents.

  """
  @behaviour Oban.Plugin

  use GenServer

  @impl Oban.Plugin
  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl Oban.Plugin
  def validate(_opts), do: :ok

  @impl GenServer
  def init(_opts) do
    :ok = Filer.PubSub.subscribe_trainer()
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(message, state)
  def handle_info(:trainer_start, state), do: {:noreply, state}
  def handle_info({:trainer_state, _}, state), do: {:noreply, state}
  def handle_info({:trainer_failed, _}, state), do: {:noreply, state}

  def handle_info({:trainer_complete, hash}, state) do
    _ = Filer.Files.list_content_ids()
    |> Enum.map(&FilerIndex.Workers.Score.new(%{"content_id" => &1, "model_hash" => hash}))
    |> Oban.insert_all()

    {:noreply, state}
  end
end
