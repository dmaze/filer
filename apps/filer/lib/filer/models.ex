defmodule Filer.Models do
  @moduledoc """
  Accessors for machine-learning models.

  The actual models are serialized and stored in the `FilerStore`.  This
  keeps a record of which models exist.

  """
  alias Filer.Models.Model
  alias Filer.Repo
  import Ecto.Query, only: [from: 2]

  @doc """
  Find or create a model record with a specific hash.

  """
  @spec model_by_hash(String.t()) :: Model.t()
  def model_by_hash(hash) do
    Filer.Repo.insert!(%Model{hash: hash},
      on_conflict: {:replace, [:hash]},
      conflict_target: [:hash]
    )
  end

  @doc """
  Get a single model record by its hash, if it exists.

  """
  @spec get_model_by_hash(String.t()) :: Model.t() | nil
  def get_model_by_hash(hash) do
    q = from m in Model, where: m.hash == ^hash
    Repo.one(q)
  end

  @doc """
  Get all of the model records.

  These are in no particular order.

  """
  @spec list_models() :: [Model.t()]
  def list_models(), do: Repo.all(Model)

  @doc """
  Get the single newest model.

  Returns `nil` if there are no models at all.  "Newest" is determined by
  the recorded insertion time in the database.

  """
  @spec newest_model() :: Model.t() | nil
  def newest_model() do
    q = from m in Model, order_by: [desc: m.inserted_at], limit: 1
    Repo.one(q)
  end
end
