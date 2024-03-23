defmodule Filer.Models.Model do
  @moduledoc """
  Ecto model object for a machine-learning model.

  This does not actually store the model itself, just a reference in the
  content store.  We only need this to keep track of which models exist.

  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "contents" do
    field :hash, :string

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
