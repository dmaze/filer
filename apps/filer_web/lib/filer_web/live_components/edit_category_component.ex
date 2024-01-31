defmodule FilerWeb.EditCategoryComponent do
  @moduledoc """
  Live component to edit a category inline.

  There must be a `category` assign, but the category may be a new empty
  category that has not yet been persisted.

  There may be a `on_change` assign.  If there is, it has a function type,
  accepting a single parameter.  The function is called when the "submit" button is pressed and the changed category has successfully been submitted, with the updated category object as its single parameter.

  The "submit" and "cancel" buttons perform live patch navigation to
  `FilerWeb.LabelsLive`.

  """
  use FilerWeb, :live_component
  alias Filer.Labels.Category

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-change="change" phx-submit="submit" phx-target={@myself}>
        <.field field={@form[:name]} />
        <div class="flex justify-end gap-3">
          <%= if @category.id == nil do %>
            <.button
              type="button"
              label="Cancel"
              icon={:x_mark}
              link_type="live_patch"
              to={~p"/labels"}
            />
            <.button type="submit" label="Add" icon={:plus} />
          <% else %>
            <.button
              type="button"
              label="Cancel"
              icon={:x_mark}
              link_type="live_patch"
              to={~p"/labels/#{@category}"}
            />
            <.button type="submit" label="Update" icon={:check} />
          <% end %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket =
      case Map.fetch(assigns, :category) do
        {:ok, category} ->
          assign(socket,
            category: category,
            form: category |> Ecto.Changeset.change() |> to_form()
          )

        _ ->
          socket
      end

    socket =
      case Map.fetch(assigns, :on_change) do
        {:ok, f} -> assign(socket, :on_change, f)
        _ -> socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket)

  def handle_event("change", %{"category" => params}, socket) do
    form = Category.changeset(socket.assigns.category, params) |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit", %{"category" => params}, socket) do
    changeset = Category.changeset(socket.assigns.category, params)

    result =
      case changeset.data.id do
        nil -> Filer.Repo.insert(changeset)
        _ -> Filer.Repo.update(changeset)
      end

    socket =
      case result do
        {:ok, category} ->
          require Logger
          Logger.info("on_change: #{inspect(Map.get(socket.assigns, :on_change))}")
          Map.get(socket.assigns, :on_change, fn _ -> nil end).(category)
          socket |> push_patch(to: ~p"/labels/#{category}")

        {:error, changeset} ->
          assign(socket, form: to_form(changeset))
      end

    {:noreply, socket}
  end
end
