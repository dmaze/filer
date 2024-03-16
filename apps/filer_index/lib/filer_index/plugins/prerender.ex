defmodule FilerIndex.Plugins.Prerender do
  @moduledoc """
  Oban plugin to prerender content.

  Currently this runs once at worker startup only.  Longer-term we expect
  this will plug into `Phoenix.PubSub` to prerender documents when they are
  discovered, and potentially to execute multiple steps of rendering.

  """
  @behaviour Oban.Plugin

  use GenServer
  alias Filer.Files

  @impl Oban.Plugin
  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @impl Oban.Plugin
  def validate(_opts), do: :ok

  @impl GenServer
  def init(_opts) do
    # create the preseed jobs
    Files.list_content_hashes()
    |> Enum.map(&FilerIndex.Workers.Render72.new(%{"hash" => &1}))
    |> Oban.insert_all()

    {:ok, nil}
  end
end
