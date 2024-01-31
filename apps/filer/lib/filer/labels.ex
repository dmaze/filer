defmodule Filer.Labels do
  @moduledoc """
  Interface to labels.

  A user may create any number of Filer.Labels.Value indicating some particular label that may be applied to documents.  Every value belongs to exactly one Filer.Labels.Category.  The user will generally experience categories and values within that, but the inference system will mostly only care about the actual values.

  A Filer.Labels.Label is a user-provided label that a given content has a specific value attached to it.

  Another type will be added for inferred labels when we create those.

  """
  alias Filer.Repo
  alias Filer.Labels.Category
  alias Filer.Labels.Value
  import Ecto.Query, only: [from: 2]

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
end
