defmodule FilerIndex.Workers.Score do
  @moduledoc """
  Oban worker to score an individual document.

  """
  use Oban.Worker, queue: :score
  import Ecto.Query, only: [from: 2]

  @impl Oban.Worker
  def perform(%{args: %{"content_id" => id}}) do
    q = from c in Filer.Files.Content, preload: [:inferences]
    content = Filer.Repo.get!(q, id)
    values = FilerIndex.Trainer.score(FilerIndex.Trainer, content)

    content
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:inferences, values)
    |> Filer.Repo.update!()

    :ok
  end
end
