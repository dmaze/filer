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
end
