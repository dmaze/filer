defmodule Filer.Files do
  @moduledoc """
  PDF files as they exist on disk.

  There is a two-level storage scheme.  A Filer.Files.File represents a
  single file, but there is no information about it beyond a hash of
  its contents.  A Filer.Files.Content then represents that content,
  which may exist in one or more files.  This scheme accommodates some
  variations like hard and symbolic links, and files moving on disk
  without their contents changing.

  """
  import Ecto.Query, only: [from: 2]

  @doc """
  Observe that a file exists.

  Given a hash of its content, ensure the content entry exists.  Create
  or update a file entry to refer to that content.

  """
  @spec observe_file(Path.t(), String.t()) :: Filer.Files.File.t()
  def observe_file(path, hash) do
    content_by_hash(hash)
    |> Ecto.build_assoc(:files, path: path)
    |> Filer.Repo.insert!(
      conflict_target: [:path],
      on_conflict: {:replace, [:content_id]}
    )
  end

  @doc """
  Compute a hash for the contents of a file path.

  This always reads the named file.  It never consults the database.

  """
  @spec file_hash(Path.t()) :: {:ok, String.t()} | {:error, File.posix()}
  def file_hash(path) do
    File.open(path, [:binary, :read], fn f ->
      IO.binstream(f, 65_536)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)
    end)
  end

  @doc """
  Determine whether a file needs to be updated.

  It does if the file does not exist in the database, or if the
  database hash disagrees with the contents of the file.  If it
  does need updating, returns the hash.

  """
  @spec file_needs_update(Path.t()) :: :ok | {:update, String.t()} | {:error, File.posix()}
  def file_needs_update(path) do
    with {:ok, hash} <- file_hash(path) do
      q = from f in Filer.Files.File, where: f.path == ^path, preload: :content

      case Filer.Repo.one(q) do
        nil ->
          {:update, hash}

        file ->
          if hash == file.content.hash, do: :ok, else: {:update, hash}
      end
    end
  end

  @doc """
  Given a file hash, get or create a content object for it.

  """
  @spec content_by_hash(String.t()) :: Filer.Files.Content.t()
  def content_by_hash(hash) do
    Filer.Repo.insert!(%Filer.Files.Content{hash: hash},
      on_conflict: {:replace, [:hash]},
      conflict_target: [:hash]
    )
  end

  @doc """
  Find some file containing a content object.

  This finds a database record, where the file's content ID is the
  specified content record, and the target file exists on disk.

  This does not check that the target file is actually readable, or
  that it contains the same content as in the hash.

  Returns `nil` if the content object has no associated files, or none
  of the recorded files exist on disk.

  """
  @spec any_file_for_content(Filer.Files.Content.t()) :: Filer.Files.File.t() | nil
  def any_file_for_content(content) do
    Ecto.assoc(content, :files)
    |> Ecto.Query.select([:path])
    |> Ecto.Query.order_by(:path)
    |> Filer.Repo.all()
    |> Stream.map(& &1.path)
    |> Stream.filter(&File.exists?/1)
    |> Enum.at(0)
  end
end
