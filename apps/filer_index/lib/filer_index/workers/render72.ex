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
      with {:ok, pdf} <- get_pdf(hash),
           {:ok, png} <- render_png(pdf) do
        FilerStore.put(FilerStore, {hash, :png, :res72}, png)
      end
    end
  end

  defp get_pdf(hash) do
    case FilerStore.get(FilerStore, {hash, :pdf}) do
      {:ok, pdf} ->
        {:ok, pdf}

      :not_found ->
        {:error, "no PDF document with hash #{hash}"}
    end
  end

  defp render_png(pdf) do
    case Filer.Render.to_png(pdf, resolution: 72) do
      {:ok, png} -> {:ok, png}
      {:error, code} -> {:error, "PDF rendering failed with code #{code}"}
      :not_found -> {:error, "PDF rendering could not find gs binary"}
    end
  end
end
