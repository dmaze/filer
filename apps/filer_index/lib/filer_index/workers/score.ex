defmodule FilerIndex.Workers.Score do
  @moduledoc """
  Oban worker to score an individual document.

  """
  use Oban.Worker, queue: :score
  alias Filer.Files
  alias Filer.Trainer

  @impl Oban.Worker
  def perform(%{args: %{"content_id" => id, "model_hash" => model_hash}}) do
    Files.update_content_inferences(id, &Trainer.score(model_hash, &1))

    :ok
  end

  # for backwards compatibility
  def perform(%{args: %{"content_id" => _} = args}) do
    case Filer.Models.newest_model() do
      # ignore
      nil -> :ok
      model -> perform(%{args | "model_hash" => model.hash})
    end
  end
end
