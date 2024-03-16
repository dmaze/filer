defmodule FilerIndex.Workers.Render72 do
  @moduledoc """
  Oban worker to render a content at 72 dpi.

  Given a content object, reads the `:pdf` format, renders it at 72 dpi, and
  writes a `:png, :res72` object back.  Raises on any error.

  """
  use Oban.Worker, queue: :render

  @impl Oban.Worker
  def perform(%{args: %{"hash" => hash}}) do
    if FilerStore.exists?(FilerStore, {hash, :png, :res72}) do
      :ok
    else
      {:ok, pdf} = FilerStore.get(FilerStore, {hash, :pdf})
      {:ok, png} = Filer.Render.to_png(pdf, resolution: 72)
      FilerStore.put(FilerStore, {hash, :png, :res72}, png)
    end
  end
end
