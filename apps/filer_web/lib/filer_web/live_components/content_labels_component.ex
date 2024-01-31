defmodule FilerWeb.ContentLabelsComponent do
  @moduledoc """
  Live component to edit a content's labels.

  The assigns must contain a `content`; its labels must be preloaded.

  """
  use FilerWeb, :live_component
  alias Filer.Files.Content
  alias Filer.Labels
  alias Filer.Labels.Value

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-change="update" phx-target={@myself}>
        <.field
          :for={c <- @categories}
          field={@form[String.to_atom("category-#{c.id}")]}
          type="select"
          options={[{"(none)", ""} | Enum.map(c.values, fn v -> {v.value, "#{v.id}"} end)]}
          label={c.name}
        />
      </.form>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    # Preload the categories
    socket = assign(socket, categories: Labels.list_categories())
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      case Map.fetch(assigns, :content) do
        {:ok, content} -> update_content(content, socket)
        :error -> socket
      end

    {:ok, socket}
  end

  @spec update_content(Content.t(), Phoenix.Socket.t()) :: Phoenix.Socket.t()
  defp update_content(content, socket) do
    # We're going to create form data for ourselves.
    # This will have one item for each category.
    form_data =
      socket.assigns.categories
      |> Enum.map(fn category -> {"category-#{category.id}", nil} end)
      |> Map.new()

    # Then take each label on the content and assign it to the right category.
    form_data =
      Enum.reduce(content.labels, form_data, fn v, f ->
        Map.put(f, "category-#{v.category_id}", "#{v.id}")
      end)

    assign(socket, content: content, form: to_form(form_data))
  end

  @impl true
  def handle_event("update", params, socket) do
    import Ecto.Query, only: [from: 2]
    require Logger

    Logger.info("params: #{inspect(params)}")
    Logger.info("values: #{inspect(Map.values(params))}")

    # Assuming there weren't multiple labels in a category, the values
    # of `params` list all of the labels (value IDs).
    value_ids =
      params
      |> Map.filter(fn {k, v} -> String.starts_with?(k, "category-") && v != "" end)
      |> Map.values()
      |> Enum.flat_map(
        &case(Integer.parse(&1)) do
          {id, ""} -> [id]
          _ -> []
        end
      )

    values = from(v in Value, where: v.id in ^value_ids) |> Filer.Repo.all()

    changeset =
      socket.assigns.content
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:labels, values)

    socket =
      case Filer.Repo.update(changeset) do
        {:ok, content} ->
          update_content(content, socket)

        {:error, _changeset} ->
          Logger.warning("could not update labels")
          socket
      end

    {:noreply, socket}
  end
end
