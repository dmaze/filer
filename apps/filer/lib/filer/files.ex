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

  ### META

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

  If this returns an existing object, nothing is preloaded.  If this creates
  a new object, a pub/sub event is sent.

  """
  @spec content_by_hash(String.t()) :: Filer.Files.Content.t()
  def content_by_hash(hash) do
    q = from c in Content, where: c.hash == ^hash

    case Repo.one(q) do
      nil -> Repo.insert!(%Content{hash: hash}) |> tap(&Filer.PubSub.broadcast_content_new(&1.id))
      content -> content
    end
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
  Replace the inferred labels for a content object.

  `inferrer` is a function that accepts a `Content` object and returns a list
  of `Value`.  These completely replace the existing inferred values on that
  content.  The existing inferences are preloaded, but nothing else.

  Returns the updated content, again with inferences but nothing else
  preloaded.  Sends a content-inferred pub/pub event on success.  Raises if
  the `id` is invalid or the update otherwise cannot happen.

  """
  @spec update_content_inferences(integer(), (Content.t() -> [Value.t()])) :: Content.t()
  def update_content_inferences(id, inferrer) do
    q = from c in Content, preload: [:inferences]
    content = Repo.get!(q, id)
    values = inferrer.(content)

    content
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:inferences, values)
    |> Repo.update!()
    |> tap(fn _ -> Filer.PubSub.broadcast_content_inferred(id) end)
  end

  ### FILES

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
          [FFile.t()]
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
  @spec get_file(String.t() | integer()) :: FFile.t() | nil
  def get_file(id) do
    q = from f in FFile, preload: [content: [:labels, :inferences]]
    get_thing(id, q)
  end

  @doc """
  Gets a single file.

  Raises `Ecto.NoResultsError` if the File does not exist.

  ## Examples

      iex> get_file!(123)
      %File{}

      iex> get_file!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_file!(integer()) :: FFile.t()
  def get_file!(id) do
    q = from f in FFile, preload: [content: [:labels, :inferences]]
    Repo.get!(q, id)
  end

  @doc """
  Gets a single file by its path.

  Returns `nil` if no file exists with the specified exact path.

  If a file is returned, its content, associated labels, and associated
  inferences are all preloaded.

  """
  @spec get_file_by_path(String.t()) :: FFile.t() | nil
  def get_file_by_path(path) do
    q = from f in FFile, where: f.path == ^path, preload: [content: [:labels, :inferences]]
    Repo.one(q)
  end

  @doc """
  Creates a file.

  ## Examples

      iex> create_file(%{field: value})
      {:ok, %File{}}

      iex> create_file(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_file(map()) :: {:ok, FFile.t()} | {:error, Ecto.Changeset.t()}
  def create_file(attrs \\ %{}) do
    %FFile{}
    |> FFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a file.

  ## Examples

      iex> update_file(file, %{field: new_value})
      {:ok, %File{}}

      iex> update_file(file, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_file(FFile.t(), map()) :: {:ok, FFile.t()} | {:error, Ecto.Changeset.t()}
  def update_file(%FFile{} = file, attrs) do
    file
    |> FFile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a file.

  ## Examples

      iex> delete_file(file)
      {:ok, %File{}}

      iex> delete_file(file)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_file(FFile.t()) :: {:ok, FFile.t()} | {:error, Ecto.Changeset.t()}
  def delete_file(%FFile{} = file) do
    Repo.delete(file)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking file changes.

  ## Examples

      iex> change_file(file)
      %Ecto.Changeset{data: %File{}}

  """
  @spec change_file(FFile.t(), map()) :: Ecto.Changeset.t(FFile.t())
  def change_file(%FFile{} = file, attrs \\ %{}) do
    FFile.changeset(file, attrs)
  end

  ### CONTENTS

  @doc """
  Returns the list of contents.

  The objects are in any order.  They have their files, inferences, and
  labels preloaded.

  ## Examples

      iex> list_contents()
      [%Content{}, ...]

  """
  @spec list_contents() :: [Content.t()]
  def list_contents() do
    q = from c in Content, preload: [:files, :inferences, :labels]
    Repo.all(q)
  end

  @doc """
  Get all of the content IDs.

  None of the other information is provided, just the IDs.  The IDs are
  not in any specific order.

  """
  @spec list_content_ids() :: [integer()]
  def list_content_ids() do
    Repo.all(from c in Content, select: c.id)
  end

  @doc """
  Get all of the content hashes.

  None of the other information is provided, just the hashes.  The hashes
  are not in any specific order.

  """
  @spec list_content_hashes() :: [String.t()]
  def list_content_hashes() do
    Repo.all(from c in Content, select: c.hash)
  end

  @doc """
  Get all of the labeled content objects.

  The objects are in any order.  The returned objects all have at least one
  label.  The labels are preloaded.

  """
  @spec list_labeled_contents() :: [Content.t()]
  def list_labeled_contents() do
    q = from c in Content, join: v in assoc(c, :labels), preload: [:labels]
    Repo.all(q)
  end

  @doc """
  Gets a single content.

  Raises `Ecto.NoResultsError` if the Content does not exist.

  ## Examples

      iex> get_content!(123)
      %Content{}

      iex> get_content!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_content!(integer()) :: Content.t()
  def get_content!(id) do
    q = from c in Content, preload: [:files, :inferences, :labels]
    Repo.get!(q, id)
  end

  @doc """
  Gets a single content by its hash.

  Returns `nil` if the Content does not exist.

  """
  @spec get_content_by_hash(String.t()) :: Content.t() | nil
  def get_content_by_hash(hash) do
    q = from c in Content, where: c.hash == ^hash, preload: [:files, :inferences, :labels]
    Repo.one(q)
  end

  @doc """
  Creates a content.

  ## Examples

      iex> create_content(%{field: value})
      {:ok, %Content{}}

      iex> create_content(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_content(map()) :: {:ok, Content.t()} | {:error, Ecto.Changeset.t()}
  def create_content(attrs \\ %{}) do
    %Content{}
    |> Content.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a content.

  ## Examples

      iex> update_content(content, %{field: new_value})
      {:ok, %Content{}}

      iex> update_content(content, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_content(Content.t(), map()) :: {:ok, Content.t()} | {:error, Ecto.Changeset.t()}
  def update_content(%Content{} = content, attrs) do
    content
    |> Content.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a content.

  ## Examples

      iex> delete_content(content)
      {:ok, %Content{}}

      iex> delete_content(content)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_content(Content.t()) :: {:ok, Content.t()} | {:error, Ecto.Changeset.t()}
  def delete_content(%Content{} = content) do
    Repo.delete(content)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking content changes.

  ## Examples

      iex> change_content(content)
      %Ecto.Changeset{data: %Content{}}

  """
  @spec change_content(Content.t(), map()) :: Ecto.Changeset.t()
  def change_content(%Content{} = content, attrs \\ %{}) do
    Content.changeset(content, attrs)
  end
end
