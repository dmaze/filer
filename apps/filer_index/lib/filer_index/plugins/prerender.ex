defmodule FilerIndex.Plugins.Prerender do
  @moduledoc """
  Oban plugin to prerender content.

  This plugin runs at two separate times.  At worker startup, it scans all
  known contents and attempts to render them.  It also subscribes to
  `Filer.PubSub` content messages, and renders new contents when they
  appear.

  """
  @behaviour Oban.Plugin

  use GenServer
  require Logger
  alias Filer.Files
  alias FilerIndex.Workers.Render72

  @impl Oban.Plugin
  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl Oban.Plugin
  def validate(_opts), do: :ok

  @impl GenServer
  def init(_opts) do
    # subscribe to events when content appears
    :ok = Filer.PubSub.subscribe_content_global()

    {:ok, %{preseeded: false}, {:continue, :preseed}}
  end

  @impl GenServer
  def handle_continue(:preseed, %{preseeded: true} = state) do
    {:noreply, state}
  end

  def handle_continue(:preseed, state) do
    case Filer.Store.whereis() do
      nil ->
        {:noreply, state, 1000}

      _ ->
        _ =
          Files.list_content_hashes()
          |> Stream.filter(&Render72.needed?/1)
          |> Enum.map(&Render72.new(%{"hash" => &1}))
          |> Oban.insert_all()

        {:noreply, %{state | preseeded: true}}
    end
  end

  @impl GenServer
  def handle_info({:content_new, id}, state) do
    case Files.get_content(id) do
      nil ->
        Logger.error("saw pubsub message for missing content id #{id}")

      %{hash: hash} ->
        changeset = Render72.new(%{"hash" => hash})

        case Oban.insert(changeset) do
          {:ok, _job} -> nil

          {:error, reason} ->
            Logger.error("could not insert render72 job: #{inspect(reason)}")
        end
    end
    {:noreply, state, {:continue, :preseed}}
  end

  def handle_info(:timeout, state) do
    {:noreply, state, {:continue, :preseed}}
  end
end
