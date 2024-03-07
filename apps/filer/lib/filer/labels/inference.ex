defmodule Filer.Labels.Inference do
  use Ecto.Schema
  import Ecto.Changeset
  alias Filer.Files.Content
  alias Filer.Labels.Value

  schema "inferences" do
    belongs_to :value, Value
    belongs_to :content, Content

    timestamps()
  end

  @doc false
  def changeset(label, attrs) do
    label
    |> cast(attrs, [])
    |> validate_required([])
    |> assoc_constraint(:value)
    |> assoc_constraint(:content)
  end
end
