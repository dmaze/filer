defmodule FilerScanner.Pruner do
  @moduledoc """
  Static task to delete files that no longer exist.

  """
  use Task, restart: :transient
  alias FilerScanner.Api

  def start_link(args) do
    args = Keyword.validate!(args, [:api, :path])
    api = Keyword.fetch!(args, :api)
    path = Keyword.fetch!(args, :path)
    Task.start_link(__MODULE__, :run, [api, path])
  end

  def run(api, path) do
    response = Api.list_files(api)
    all_files = response.body["data"]
    Enum.each(all_files, &check_file(&1, api, path))
  end

  defp check_file(datum, api, path) do
    filename = Path.join(path, datum["path"])
    if !File.exists?(filename) do
      Api.delete_file(api, datum["id"])
    end
  end
end
