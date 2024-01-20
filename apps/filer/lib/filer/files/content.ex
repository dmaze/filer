defmodule Filer.Files.Content do
  @moduledoc """
  Model object for a file's content.

  This is not tied to a single filesystem entry.  If a file moves, its
  file object may be updated without recomputing the content.

  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Filer.Files.File
  alias Filer.Labels.Label

  schema "contents" do
    field :hash, :string
    has_many :files, File
    has_many :labels, Label

    timestamps()
  end

  @doc false
  def changeset(content, attrs) do
    content
    |> cast(attrs, [:hash])
    |> validate_required([:hash])
    |> unique_constraint(:hash)
  end
end
