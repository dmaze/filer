defmodule FilerIndex.Workers.Score do
  @moduledoc """
  Oban worker to score an individual document.

  """
  use Oban.Worker, queue: :score
  import Ecto.Query, only: [from: 2]

  @impl Oban.Worker
  def perform(%{args: %{"content_id" => id, "model_hash" => model_hash}}) do
    q = from c in Filer.Files.Content, preload: [:inferences]
    content = Filer.Repo.get!(q, id)
    values = FilerIndex.Trainer.score(FilerIndex.Trainer, model_hash, content)

    content
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:inferences, values)
    |> Filer.Repo.update!()

    :ok
  end

  # for backwards compatibility
  def perform(%{args: %{"content_id" => _} = args}) do
    case Filer.Models.newest_model() do
      nil -> :ok # ignore
      model -> perform(%{args | "model_hash" => model.hash})
    end
  end
end
