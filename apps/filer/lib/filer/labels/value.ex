defmodule Filer.Labels.Value do
  use Ecto.Schema
  import Ecto.Changeset
  alias Filer.Files.Content
  alias Filer.Labels.Category
  alias Filer.Labels.Label

  schema "values" do
    field :value, :string
    belongs_to :category, Category
    many_to_many :labelled, Content, join_through: Label, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(value, attrs) do
    value
    |> cast(attrs, [:value])
    |> validate_required([:value])
    |> assoc_constraint(:category)
  end
end
