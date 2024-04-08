defmodule FilerWeb.FileJSON do
  alias Filer.Files.File

  @doc """
  Renders a list of files.
  """
  def index(%{files: files}) do
    %{data: Enum.map(files, &data/1)}
  end

  @doc """
  Renders a single file.
  """
  def show(%{file: file}) do
    %{data: data(file)}
  end

  @doc """
  Produce the data structure for a file.
  """
  def data(%File{} = file) do
    data = %{
      id: file.id,
      path: file.path
    }

    data =
      if Ecto.assoc_loaded?(file.content) do
        Map.put(data, :content, FilerWeb.ContentJSON.data(file.content))
      else
        data
      end

    data
  end
end
