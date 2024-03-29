defmodule Filer.Labels.Category do
  use Ecto.Schema
  import Ecto.Changeset
  alias Filer.Labels.Value

  schema "categories" do
    field :name, :string
    has_many :values, Value

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
