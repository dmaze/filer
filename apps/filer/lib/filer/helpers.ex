defmodule Filer.Helpers do
  @moduledoc """
  Assorted internal helpers.

  """

  @doc """
  Get an arbitrary database object by primary key.

  The `id` may usefully be a string or an integer, but the function supports
  anything.  If it is a string, it must parse exactly to an integer.

  `queryable` is usually an Ecto schema module, maybe with preloads applied.

  This is intended to help with getters given untrusted ID inputs, for example

      def get_something(id) do
        query = from s in Something, preload: [:related]
        get_thing(id, query)
      end

  Returns the item from `queryable` with the given `id`.  Returns `nil` if the
  `id` is not an integer or an integer-syntax string, or if an object with
  that ID does not exist in the database.

  """
  @spec get_thing(any(), Ecto.Queryable.t()) :: any()
  def get_thing(id, queryable)

  def get_thing(id, queryable) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> get_thing(int_id, queryable)
      _ -> nil
    end
  end

  def get_thing(id, queryable) when is_integer(id) do
    Filer.Repo.get(queryable, id)
  end

  def get_thing(_, _), do: nil
end
