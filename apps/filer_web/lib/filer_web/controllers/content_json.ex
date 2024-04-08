defmodule FilerWeb.ContentJSON do
  alias Filer.Files.Content

  @doc """
  Renders a list of contents.
  """
  def index(%{contents: contents}) do
    %{data: Enum.map(contents, &data/1)}
  end

  @doc """
  Renders a single content.
  """
  def show(%{content: content}) do
    %{data: data(content)}
  end

  @doc """
  Produce the data structure for a content.
  """
  def data(%Content{} = content) do
    data = %{
      id: content.id,
      hash: content.hash
    }

    data =
      if Ecto.assoc_loaded?(content.files) do
        Map.put(data, :files, Enum.map(content.files, &FilerWeb.FileJSON.data/1))
      else
        data
      end

    data
  end
end
