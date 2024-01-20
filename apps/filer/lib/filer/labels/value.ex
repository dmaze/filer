defmodule Filer.Labels.Value do
  use Ecto.Schema
  import Ecto.Changeset
  alias Filer.Labels.Category

  schema "values" do
    field :value, :string
    belongs_to :category, Category

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
