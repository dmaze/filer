defmodule FilerIndex.Observer do
  @moduledoc """
  Observe individual files.

  `observe/1` gets called when a new file is seen.  This consults with
  the database and does the work required to index the document.

  """
  require Logger

  @doc """
  Observe an individual file.

  If `path` already exists in the index with its current contents, do
  nothing.  Otherwise store it in the index and do additional
  computation as required.

  For concurrency and failure-domain isolation, this function may be
  run in a dedicated task.

  """
  @spec observe(Path.t()) :: nil
  def observe(path) do
    case Filer.Files.file_needs_update(path) do
      :ok ->
        Logger.info("#{path} is up to date")
        nil

      {:error, reason} ->
        Logger.error("could not read #{path}: #{reason}")
        # might consider removing it from the database
        nil

      {:update, hash} ->
        Logger.info("updating #{path} (#{hash})")
        Filer.Files.observe_file(path, hash)
        nil
    end
  end
end
