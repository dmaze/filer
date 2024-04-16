defmodule FilerScanner.Scanner do
  @moduledoc """
  Scan the filesystem for new and updated files.

  This can run as a static task.  If so, it reads all of the files in the
  provided path prefix, and compares them to what exists in the remote server.

  This also provides public functions to update a specific file, which may
  be invoked from other places like the background watcher.

  """
  use Task, restart: :transient
  alias FilerScanner.Api
  require Logger

  def start_link(args) do
    args = Keyword.validate!(args, [:api, :path])
    api = Keyword.fetch!(args, :api)
    path = Keyword.fetch!(args, :path)
    Task.start_link(__MODULE__, :run, [api, path])
  end

  @doc """
  Run a one-off filesystem scan.

  All local files are checked and uploaded if needed.  All files that are
  listed on the server are checked to see if they exist locally.

  """
  @spec run(Api.t(), String.t()) :: term()
  def run(api, path) do
    scan(api, path, "")
  end

  defp scan(api, path, dir) do
    File.ls!(Path.join(path, dir))
    |> Enum.each(fn f ->
      f = Path.join(dir, f)

      if File.dir?(Path.join(path, f)) do
        scan(api, path, f)
      else
        check(api, path, f)
      end
    end)
  end

  @doc """
  Check that a file matches what the server believes.

  This reads in the file, calculates its SHA-256 hash, and checks that the
  server has the same file with the same content record.  Creates a content
  record and creates or updates a file record if needed.  Deletes a file
  record if the named file does not exist.

  The `path` is the configured path prefix, and the `filename` is the
  path relative to that base path.  Only the `filename` part is sent to the
  server.

  """
  @spec check(Api.t(), String.t(), String.t()) :: :ok | :error
  def check(api, path, filename) do
    case File.read(Path.join(path, filename)) do
      {:ok, body} ->
        check_file(api, filename, body)

      {:error, :enoent} ->
        delete_file(api, filename)

      {:error, reason} ->
        Logger.error("Could not read #{filename}: #{:file.format_error(reason)}")
        :error
    end
  end

  @spec check_file(Api.t(), String.t(), binary()) :: :ok | :error
  defp check_file(api, filename, body) do
    hash = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
    # Three cases:
    # 1. The file exists and its content has the right hash
    # 2. The file exists but its content has the wrong hash
    # 3. The file does not exist
    #
    # In the latter two cases, there are two subcases
    # a. ...but another content exists with the hash
    # b. ...but the content does not exist
    files = Api.list_files_by_path(api, filename)

    case files.body["data"] do
      # the file exists with the right hash
      [%{"content" => %{"hash" => ^hash}}] ->
        :ok

      # the file exists with the wrong hash
      [%{"id" => id}] ->
        with {:ok, content_id} <- check_content(api, hash, body, filename) do
          _ = Api.change_file_content(api, id, content_id)
          Logger.info("#{filename} updated with new content")
          :ok
        end

      # the file does not exist
      [] ->
        with {:ok, content_id} <- check_content(api, hash, body, filename) do
          _ = Api.create_file(api, filename, content_id)
          Logger.info("#{filename} created")
          :ok
        end
    end
  end

  defp delete_file(api, filename) do
    files = Api.list_files_by_path(api, filename)

    case files.body["data"] do
      [%{"id" => id}] ->
        _ = Api.delete_file(api, id)
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Check that a content hash exists on the server.

  We assume there are no SHA-256 hash conflicts.  If a content with the
  specified hash exists on the server, return its ID; if not, create a
  new content with the specified body.

  """
  @spec check_content(Api.t(), String.t(), String.t(), String.t()) :: {:ok, integer()} | :error
  def check_content(api, hash, body, filename) do
    contents = Api.list_contents_by_hash(api, hash)

    case contents.body["data"] do
      [%{"id" => id, "hash" => ^hash}] ->
        {:ok, id}

      [%{"hash" => other_hash}] ->
        Logger.error("#{filename} has SHA-256 hash #{hash} but retrieved hash #{other_hash}")
        :error

      [] ->
        resp = Api.create_content(api, body)

        case resp.body["data"] do
          %{"id" => id, "hash" => ^hash} ->
            Logger.info("#{filename}: uploaded content with SHA-256 hash #{hash}")
            {:ok, id}

          %{"hash" => other_hash} ->
            Logger.error("#{filename} has SHA-256 hash #{hash} but uploaded hash #{other_hash}")
            :error

          other ->
            Logger.error(
              "#{filename} has SHA-256 hash #{hash} but got weird content response #{inspect(other)}"
            )
            :error
        end

      _ ->
        Logger.error("#{filename} has SHA-256 hash #{hash} but found multiple server copies")
    end
  end
end
