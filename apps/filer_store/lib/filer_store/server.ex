defmodule FilerStore.Server do
  @moduledoc """
  Server implementation of the store.

  """
  use GenServer
  require Logger

  @typedoc """
  Options for the store.

  `:directory` contains the directory to hold the store data.

  """
  @type option() :: {:directory, String.t()}

  # Internal state for the server.
  @typep state() :: %{directory: String.t()}

  @doc """
  Start the server as a supervised process.

  """
  @spec start_link([option() | GenServer.option()]) :: GenServer.on_start()
  def start_link(opts) do
    {store_opts, genserver_opts} = Keyword.split(opts, [:directory])
    GenServer.start_link(__MODULE__, store_opts, genserver_opts)
  end

  @impl true
  @spec init([option()]) :: {:ok, state()}
  def init(args) do
    state = %{directory: Keyword.get(args, :directory)}
    Logger.info("Filer store is started")
    {:ok, state}
  end

  @spec content_directory(state(), String.t()) :: String.t()
  defp content_directory(state, hash) do
    prefix = String.slice(hash, 0, 2)
    Path.join([state.directory, "content", prefix, hash])
  end

  @spec object_path(state(), Filer.Store.address()) :: String.t()
  defp object_path(state, {hash, format}) do
    object_path(state, {hash, format, nil})
  end

  defp object_path(state, {hash, format, nil}) do
    object_path(state, hash, Atom.to_string(format), "_")
  end

  defp object_path(state, {hash, format, qualifier}) do
    object_path(state, hash, Atom.to_string(format), Atom.to_string(qualifier))
  end

  @spec object_path(state(), String.t(), String.t(), String.t()) :: String.t()
  defp object_path(state, hash, ext, name) do
    directory = content_directory(state, hash)
    filename = "#{name}.#{ext}"
    Path.join([directory, filename])
  end

  @spec handle_call(Filer.Store.message(), GenServer.from(), state()) :: any()
  @impl true
  def handle_call(message, from, state)

  def handle_call({:put, address, content}, _, state) do
    path = object_path(state, address)
    directory = Path.dirname(path)

    with :ok <- File.mkdir_p(directory),
         :ok <- File.write(object_path(state, address), content) do
      :ok
    else
      {:error, code} -> Logger.error("Could not write #{path}: #{inspect(code)}")
    end

    {:reply, :ok, state}
  end

  def handle_call({:get, address}, _, state) do
    path = object_path(state, address)

    case File.read(path) do
      {:ok, binary} ->
        {:reply, {:ok, binary}, state}

      {:error, :enoent} ->
        Logger.info("Could not read #{path}: not found (normal)")
        {:reply, :not_found, state}

      {:error, code} ->
        Logger.error("Could not read #{path}: #{inspect(code)}")
        {:reply, :not_found, state}
    end
  end

  def handle_call({:exists?, address}, _, state) do
    path = object_path(state, address)
    exists = File.exists?(path)
    {:reply, exists, state}
  end

  def handle_call({:delete, address}, _, state) do
    path = object_path(state, address)
    case File.rm(path) do
      :ok -> nil
      {:error, code} -> Logger.error("Could not delete #{path}: #{inspect(code)}")
    end
    {:reply, :ok, state}
  end

  def handle_call({:content_exists?, hash}, _, state) do
    path = content_directory(state, hash)
    exists = File.dir?(path)
    {:reply, exists, state}
  end

  def handle_call({:delete_content, hash}, _, state) do
    path = content_directory(state, hash)
    case File.rm_rf(path) do
      {:ok, _files} -> nil
      {:error, code, file} -> Logger.error("Could not delete #{path}: #{inspect(code)} at #{file}")
    end
    {:reply, :ok, state}
  end
end
