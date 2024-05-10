defmodule Filer.Store do
  @moduledoc """
  Object storage for files.

  The storage is based on hash-addressable contents, with multiple formats.
  The functions here take a mandatory format, usually `:pdf` or `:png`, plus
  an optional qualifier atom.  This module itself does not define any specific
  formats or qualifiers.

  All of these functions make calls to a server.  The server itself does not
  do computation on the files, and these functions should all return quickly.
  The server itself is in the `:filer_store` application; in a distributed
  environment, other components will not explicitly depend on this.

  There is normally only one instance of the store, even in a distributed
  application, and this uses the `:global` registry to record this.  The
  API here supports passing the address of the store, but in typical use that
  parameter should be omitted.

  """

  @typedoc """
  Hash of a content object.

  This is canonically the SHA-256 hash of the original file.

  """
  @type hash() :: String.t()

  @typedoc """
  Format of a content object.

  The store does not define any particular formats.  This will typically be
  a well-known file-extension atom, like `:pdf` or `:png`.

  """
  @type format() :: atom()

  @typedoc """
  Qualifier for a particular content object.

  This defines some variant of a content object; for example, a PNG file at
  a specific resolution.  The store does not define any specific qualifiers,
  except that `nil` is a default representation.

  """
  @type qualifier() :: atom()

  @typedoc """
  "Address" of a specific content object.

  """
  @type address() :: {hash(), format()} | {hash(), format(), qualifier()}

  @typedoc """
  Messages that may be sent to the server process.

  """
  @type message() ::
          {:put, address(), binary()}
          | {:get, address()}
          | {:exists?, address()}
          | {:delete, address()}
          | {:content_exists?, hash()}
          | {:delete_content, hash()}

  @doc """
  Add some object to the store.

  If an object already exists with the specified hash, format, and qualifier,
  it is replaced.

  Unconditionally returns `:ok`, even if there is an internal error inside
  the server.

  ### Examples

      iex> put({hash, :pdf}, binary)
      :ok

  """
  @spec put(GenServer.server(), address(), binary()) :: :ok
  def put(pid \\ {:global, FilerStore}, address, bytes) do
    call(pid, {:put, address, bytes})
  end

  @doc """
  Get some object from the store.

  """
  @spec get(GenServer.server(), address) :: {:ok, binary()} | :not_found
  def get(pid \\ {:global, FilerStore}, address) do
    call(pid, {:get, address})
  end

  @doc """
  Determine whether some specific object exists in the store.

  """
  @spec exists?(GenServer.server(), address()) :: boolean()
  def exists?(pid \\ {:global, FilerStore}, address) do
    call(pid, {:exists?, address})
  end

  @doc """
  Delete a specific object from the store.

  """
  @spec delete(GenServer.server(), address()) :: :ok
  def delete(pid \\ {:global, FilerStore}, address) do
    call(pid, {:delete, address})
  end

  @doc """
  Determine whether some content exists in the store.

  It is not guaranteed to have any particular objects in it.  It exists if
  `put/5` has ever been called for the hash, and `delete_content/2` has not.
  Of note the content will still exist even if all of the objects in it have
  been deleted.

  """
  @spec content_exists?(GenServer.server(), hash()) :: boolean()
  def content_exists?(pid \\ {:global, FilerStore}, hash) do
    call(pid, {:content_exists?, hash})
  end

  @doc """
  Delete some content from the store.

  This also deletes all of the objects corresponding to the content hash.

  """
  @spec delete_content(GenServer.server(), hash()) :: :ok
  def delete_content(pid \\ {:global, FilerStore}, hash) do
    call(pid, {:delete_content, hash})
  end

  @doc """
  Get the location of the store server, if it is running.

  """
  def whereis(pid \\ {:global, FilerStore}) do
    GenServer.whereis(pid)
  end

  # Send a message to the server.
  #
  # Exists principally for type-checking purposes.
  @spec call(GenServer.server(), message()) :: any()
  defp call(pid, message), do: GenServer.call(pid, message)
end
