defmodule FilerIndex.Task.Score do
  @moduledoc """
  Task to score an individual document.

  """

  @spec process(Filer.Files.Content.t(), GenServer.server()) :: Filer.Filer.Content.t()
  def process(content, trainer) do
    values = FilerIndex.Trainer.score(trainer, content)

    content
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:inferences, values)
    |> Filer.Repo.update!()
  end
end
