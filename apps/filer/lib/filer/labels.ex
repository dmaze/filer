defmodule Filer.Labels do
  @moduledoc """
  Interface to labels.

  A user may create any number of Filer.Labels.Value indicating some particular label that may be applied to documents.  Every value belongs to exactly one Filer.Labels.Category.  The user will generally experience categories and values within that, but the inference system will mostly only care about the actual values.

  A Filer.Labels.Label is a user-provided label that a given content has a specific value attached to it.

  Another type will be added for inferred labels when we create those.

  """
  import Ecto.Query, only: [from: 2]
  import Filer.Helpers
  alias Filer.Labels.{Category, Value}
  alias Filer.Repo

  @doc """
  Get all of the categories.

  The categories are sorted in order by name.  They include their values preloaded, also sorted by name.

  """
  @spec list_categories() :: list(Category.t())
  def list_categories() do
    values = from v in Value, order_by: v.value
    categories = from c in Category, preload: [values: ^values], order_by: c.name
    Repo.all(categories)
  end

  @doc """
  Create a new category.

  The category is not persisted in the database.

  """
  @spec new_category() :: Category.t()
  def new_category(), do: %Category{}

  @doc """
  Retrieve a single category by ID.

  If the ID is a string, parse it to an integer.  Then get the single
  category object with that ID.  Returns `nil` if the ID does not exist or
  if a string-format ID is not an integer.

  The category's values are preloaded and ordered by name.  The values'
  associated contents are not preloaded.

  """
  @spec get_category(String.t() | integer()) :: Category.t() | nil
  def get_category(id) do
    values = from v in Value, order_by: v.value
    q = from c in Category, preload: [values: ^values]
    get_thing(id, q)
  end

  @doc """
  Delete a category object.

  """
  @spec delete_category(Category.t()) :: {:ok, Category.t()} | {:error, Ecto.Changeset.t()}
  def delete_category(category) do
    Repo.delete(category)
  end

  @doc """
  Create a new value in some category.

  Returns `nil` if the provided category is `nil`, or if it is not yet
  persisted to the database.

  """
  @spec new_value(Category.t() | nil) :: Value.t() | nil
  def new_value(category)
  def new_value(nil), do: nil
  def new_value(%{id: nil}), do: nil
  def new_value(category), do: Ecto.build_assoc(category, :values)

  @doc """
  Retrieve a single value by ID.

  If the ID is a string, parse it to an integer.  Then get the single
  value object with that ID.  Returns `nil` if the ID does not exist or
  if a string-format ID is not an integer.

  Nothing is preloaded in the resulting value.

  """
  @spec get_value(String.t() | integer()) :: Value.t() | nil
  def get_value(id), do: get_thing(id, Value)

  @doc """
  Delete a value object.

  """
  @spec delete_value(Value.t()) :: {:ok, Value.t()} | {:error, Ecto.Changeset.t()}
  def delete_value(value) do
    Repo.delete(value)
  end
end
