defmodule FilerIndex.Task.Render72 do
  @moduledoc """
  Task to render a content at 72 dpi.

  Given a content object, reads the `:pdf` format, renders it at 72 dpi, and
  writes a `:png, :res72` object back.  Raises on any error.

  """

  @spec process(Filer.Files.Content.t(), GenServer.t()) :: :ok
  def process(content, filer_store) do
    hash = content.hash

    if FilerStore.exists?(filer_store, {hash, :png, :res72}) do
      :ok
    else
      {:ok, pdf} = FilerStore.get(filer_store, {hash, :pdf})
      {:ok, png} = Filer.Render.to_png(pdf, resolution: 72)
      FilerStore.put(filer_store, {hash, :png, :res72}, png)
    end
  end
end
