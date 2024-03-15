defmodule FilerWeb.LiveComponents do
  @moduledoc """
  Plain-component wrappers for live components.

  These have two advantages: they are somewhat more compact than explicit
  live-module syntax, and they allow declaring attributes that can be
  statically checked.

  """
  use Phoenix.Component

  attr :id, :string,
    default: "choose-labels",
    doc:
      "Identifier for the component, must be unique across all instances of this component type"

  attr :on_change, :any, required: true, doc: "Callback when the label selection changes"

  @doc """
    Choose an arbitrary set of labels.

    Intended for use as a filter.

  """
  def choose_labels(assigns) do
    ~H"""
    <.live_component module={FilerWeb.ChooseLabelsComponent} id={@id} on_change={@on_change} />
    """
  end

  attr :id, :string,
    default: "labels",
    doc:
      "Identifier for the component, must be unique across all instances of this component type"

  attr :content, Filer.Files.Content, required: true, doc: "Content object to label"

  @doc """
  Edit the labels of a content object.

  """
  @spec content_labels(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def content_labels(assigns) do
    ~H"""
    <.live_component module={FilerWeb.ContentLabelsComponent} id={@id} content={@content} />
    """
  end

  attr :id, :string,
    doc:
      "Identifier for the component.  Must be unique across all instances of this component type.  Defaults to the category's ID."

  attr :category, Filer.Labels.Category, required: true, doc: "Category object to edit."

  attr :on_change, :any,
    doc:
      "Callback when the category successfully changes.  Function of a single category parameter."

  @doc """
  Edit a category object and more specifically its name.

  Presents as a new category if the specified category object does not have an ID, or an edit if it does.

  """
  @spec edit_category(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def edit_category(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> assigns.category.id || "" end)
      |> assign_new(:on_change, fn -> fn _ -> nil end end)

    ~H"""
    <.live_component
      module={FilerWeb.EditCategoryComponent}
      id={@id}
      category={@category}
      on_change={@on_change}
    />
    """
  end

  attr :id, :string,
    doc:
      "Identifier for the component.  Must be unique across all instances of this component type.  Defaults to the value's ID."

  attr :value, Filer.Labels.Value, required: true, doc: "Value object to edit."

  @doc """
  Edit a value object and more specifically its string value.

  Presents as a new value if the specified value object does not have an ID, or an edit if it does.

  """
  @spec edit_value(Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()
  def edit_value(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> assigns.value.id || "" end)

    ~H"""
    <.live_component module={FilerWeb.EditValueComponent} id={@id} value={@value} />
    """
  end
end
