defmodule FilerWeb.EditValueComponent do
  @moduledoc """
  Live component to edit a value inline.

  There must be a `value` assign, but the value may be a new empty
  value that has not yet been persisted.

  The "submit" and "cancel" buttons perform live patch navigation to
  `FilerWeb.LabelsLive`.

  """
  use FilerWeb, :live_component
  alias Filer.Labels.Value

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-change="change" phx-submit="submit">
        <.field field={@form[:value]} />
        <div class="flex justify-end gap-3">
          <%= if @value.id == nil do %>
            <.button
              type="button"
              label="Cancel"
              icon={:x_mark}
              link_type="live_patch"
              to={~p"/labels/#{@value.category_id}"}
            />
            <.button type="submit" label="Add" icon={:plus} />
          <% else %>
            <.button
              type="button"
              label="Cancel"
              icon={:x_mark}
              link_type="live_patch"
              to={~p"/labels/#{@value.category_id}/values/#{@value}"}
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
      case Map.fetch(assigns, :value) do
        {:ok, value} ->
          assign(socket,
            value: value,
            form: value |> Ecto.Changeset.change() |> to_form()
          )

        _ ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(event, params, socket)

  def handle_event("change", %{"value" => params}, socket) do
    form = Value.changeset(socket.assigns.value, params) |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit", %{"category" => params}, socket) do
    changeset = Value.changeset(socket.assigns.value, params)

    result =
      case changeset.data.id do
        nil -> Filer.Repo.insert(changeset)
        _ -> Filer.Repo.update(changeset)
      end

    socket =
      case result do
        {:ok, value} ->
          socket
          |> push_patch(to: ~p"/labels/#{value.category_id}/values/#{value}")

        {:error, changeset} ->
          assign(socket, form: to_form(changeset))
      end

    {:noreply, socket}
  end
end
