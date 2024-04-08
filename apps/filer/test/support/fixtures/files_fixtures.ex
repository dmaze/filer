defmodule Filer.FilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Filer.Files` context.
  """

  @doc """
  Generate a content.
  """
  def content_fixture(attrs \\ %{}) do
    {:ok, content} =
      attrs
      |> Enum.into(%{
        hash: "some hash"
      })
      |> Filer.Files.create_content()

    content
  end

  @doc """
  Generate a file.
  """
  def file_fixture(attrs \\ %{}) do
    {:ok, file} =
      attrs
      |> Enum.into(%{
        path: "some path"
      })
      |> Filer.Files.create_file()

    file
  end
end
