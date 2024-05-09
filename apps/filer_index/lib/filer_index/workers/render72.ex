defmodule FilerIndex.Workers.Render72 do
  @moduledoc """
  Oban worker to render a content at 72 dpi.

  Given a content object, reads the `:pdf` format, renders it at 72 dpi, and
  writes a `:png, :res72` object back.  Raises on any error.

  """
  use Oban.Worker, queue: :render

  @doc """
  Determine if a job needs to run for a given content hash.

  """
  @spec needed?(String.t()) :: boolean()
  def needed?(hash) do
    !Filer.Store.exists?({hash, :png, :res72})
  end

  @impl Oban.Worker
  def perform(%{args: %{"hash" => hash}}) do
    if Filer.Store.exists?({hash, :png, :res72}) do
      :ok
    else
      with {:ok, pdf} <- get_pdf(hash),
           {:ok, png} <- render_png(pdf) do
        Filer.Store.put({hash, :png, :res72}, png)
      end
    end
  end

  defp get_pdf(hash) do
    case Filer.Store.get({hash, :pdf}) do
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
