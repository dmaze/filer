defmodule Filer.Files.File do
  @moduledoc """
  Model object for a file on disk.

  A file has a path and a specific content entry but no other useful
  attributes.  The more interesting properties of the file will be
  associated with its content.

  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Filer.Files.Content

  schema "files" do
    field :path, :string
    belongs_to :content, Content

    timestamps()
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, [:path, :content_id])
    |> validate_required([:path])
    |> unique_constraint(:path)
    |> assoc_constraint(:content)
  end
end
