defmodule FilerWeb.ChooseLabelsComponent do
  @moduledoc """
  Live component to choose some labels.

  There must be an `on_change` assign, a function of type `t:on_change/0`.

  """
  use FilerWeb, :live_component
  alias Filer.Labels
  alias Filer.Labels.{Category, Value}

  @typedoc """
  Type of the callback for the `on_change` assign.

  The return value is ignored.

  """
  @type on_change() :: (category_map() -> term())

  @typedoc """
  The map of categories chosen by the selector.

  """
  @type category_map() :: %{Category.t() => category_value()}

  @typedoc """
  What is chosen for a specific category.

  """
  @type category_value() :: :none | :any | {:value, Value.t()}

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-change="update" phx-target={@myself}>
        <.field
          :for={c <- @categories}
          field={@form[String.to_atom("category-#{c.id}")]}
          type="select"
          options={[
            {"(any)", "any"},
            {"(none)", "none"} | Enum.map(c.values, fn v -> {v.value, "value-#{v.id}"} end)
          ]}
          label={c.name}
        />
      </.form>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    categories = Labels.list_categories()
    form = categories |> Map.new(&{"category-#{&1.id}", "any"}) |> to_form()
    socket = assign(socket, categories: Labels.list_categories(), form: form)
    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    require Logger
    result = find_all_values(socket.assigns.categories, params)
    on_change = Map.get(socket.assigns, :on_change, fn _ -> nil end)
    on_change.(result)
    {:noreply, socket}
  end

  @spec find_all_values([Category.t()], map()) :: category_map()
  def find_all_values(categories, params) do
    categories
    |> Enum.map(&{&1, find_value(&1, params)})
    |> Map.new()
  end

  @spec find_value(Category.t(), map()) :: category_value()
  defp find_value(category, params) do
    case Map.get(params, "category-#{category.id}") do
      "any" ->
        :any

      "none" ->
        :none

      s when is_binary(s) ->
        case Enum.find(category.values, &(s == "value-#{&1.id}")) do
          nil -> :any
          v -> {:value, v}
        end

      _ ->
        :any
    end
  end
end
