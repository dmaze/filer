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
  alias Filer.Files.Content
  alias Filer.Files.File, as: FFile
  alias Filer.Labels.{Inference, Value}
  import Filer.Helpers
  alias Filer.Repo

  @doc """
  Observe that a file exists.

  Given a hash of its content, ensure the content entry exists.  Create
  or update a file entry to refer to that content.

  """
  @spec observe_file(Path.t(), String.t()) :: Filer.Files.File.t()
  def observe_file(path, hash) do
    content_by_hash(hash)
    |> Ecto.build_assoc(:files, path: path)
    |> Repo.insert!(
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
      q = from f in FFile, where: f.path == ^path, preload: :content

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

  If this returns an existing object, nothing is preloaded.

  """
  @spec content_by_hash(String.t()) :: Filer.Files.Content.t()
  def content_by_hash(hash) do
    Filer.Repo.insert!(%Content{hash: hash},
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

  @doc """
  Get many or all of the files.

  The files are in order by path.  The contents and their associated
  inferred values are preloaded.

  The set of files can be filtered by passing additional keyword options:

  `:inferred_values` provides a list of `Value` objects, and files' contents
  must have all of the specified values assigned from inference.  If an empty
  list is provided, then there is no filtering on specific values.

  `:no_inferred_categories` provides a list of `Category` objects, and files'
  contents must not have any value in the specified categories assigned from
  inference.  If an empty list is provided, then there is no filtering on
  missing categories.

  """
  @spec list_files([{:inferred_values, [Value.t()]} | {:no_inferred_categories, [Category.t()]}]) ::
          list(FFile)
  def list_files(opts \\ []) do
    import Ecto.Query, only: [dynamic: 2, from: 2]

    has_values =
      opts
      |> Keyword.get(:inferred_values, [])
      |> Enum.map(& &1.id)
      |> case do
        [] ->
          true

        value_ids ->
          dynamic(
            [content: c],
            exists(
              from i in Inference,
                where: i.content_id == parent_as(:content).id and i.value_id in ^value_ids,
                select: 1
            )
          )
      end

    has_categories =
      opts
      |> Keyword.get(:no_inferred_categories, [])
      |> Enum.map(& &1.id)
      |> case do
        [] ->
          true

        category_ids ->
          dynamic(
            [content: c],
            not exists(
              from i in Inference,
                join: v in assoc(i, :value),
                where: i.content_id == parent_as(:content).id and v.category_id in ^category_ids
            )
          )
      end

    query =
      from f in FFile,
        as: :file,
        join: c in assoc(f, :content),
        as: :content,
        where: ^has_values,
        where: ^has_categories,
        preload: [content: c],
        order_by: [asc: f.path]

    Filer.Repo.all(query)
  end

  @doc """
  Retrieve a single file by ID.

  If the ID is a string, parse it to an integer.  Then get the single
  file object with that ID.  Returns `nil` if the ID does not exist or
  if a string-format ID is not an integer.

  The file's content and its associated labels and inferences are preloaded.

  """
  @spec get_file(String.t() | integer()) :: File.t() | nil
  def get_file(id) do
    q = from f in FFile, preload: [content: [:labels, :inferences]]
    get_thing(id, q)
  end

  @doc """
  Get all of the content objects.

  The objects are in any order.  They have their files, inferences, and
  labels preloaded.

  """
  @spec list_contents() :: [Content]
  def list_contents() do
    q = from c in Content, preload: [:files, :inferences, :labels]
    Repo.all(q)
  end

  @doc """
  Get all of the content IDs.

  None of the other information is provided, just the IDs.  The IDs are
  not in any specific order.

  """
  def list_content_ids() do
    Repo.all(from c in Content, select: c.id)
  end

  @doc """
  Get all of the content hashes.

  None of the other information is provided, just the hashes.  The hashes
  are not in any specific order.

  """
  def list_content_hashes() do
    Repo.all(from c in Content, select: c.hash)
  end

  @doc """
  Get all of the labeled content objects.

  The objects are in any order.  The returned objects all have at least one
  label.  The labels are preloaded.

  """
  @spec list_labeled_contents() :: [Content]
  def list_labeled_contents() do
    q = from c in Content, join: v in assoc(c, :labels), preload: [:labels]
    Repo.all(q)
  end
end
