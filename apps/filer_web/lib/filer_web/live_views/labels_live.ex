defmodule FilerWeb.LabelsLive do
  use FilerWeb, :live_view
  import Ecto.Query, only: [from: 2]
  alias Filer.Labels.Category
  alias Filer.Labels.Value
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4">
      <.category_list categories={@categories} />
      <div>
        <%= if not(is_nil(@changeset)) and is_struct(@changeset.data, Category) do %>
          <.category_form changeset={@changeset} form={@form} />
        <% else %>
          <div :if={@category} class="flex gap-2">
            <.h4 class="grow"><%= @category.name %></.h4>
            <%= if is_nil(@changeset) do %>
              <.button label="Delete" icon={:trash} phx-click="delete_category" />
              <.button
                label="Edit"
                icon={:pencil}
                link_type="live_patch"
                to={~p"/labels/#{@category}/edit"}
              />
              <.button
                label="Add Value"
                icon={:plus}
                link_type="live_patch"
                to={~p"/labels/#{@category}/values/new"}
              />
            <% end %>
          </div>
        <% end %>
        <%= if not(is_nil(@category)) do %>
          <%= if not(is_nil(@changeset)) and is_struct(@changeset.data, Value) do %>
            <.value_form category={@category} changeset={@changeset} form={@form} />
          <% else %>
            <div :if={@value} class="flex gap-2">
              <.h5 class="grow"><%= @value.value %></.h5>
              <%= if is_nil(@changeset) do %>
                <.button label="Delete" icon={:trash} phx-click="delete_value" />
                <.button
                  label="Edit"
                  icon={:pencil}
                  link_type="live_patch"
                  to={~p"/labels/#{@category}/values/#{@value}/edit"}
                />
              <% end %>
            </div>
          <% end %>
          <.category_values category={@category} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :categories, :list

  def category_list(assigns) do
    ~H"""
    <div>
      <div class="flex">
        <div class="grow">
          <.h3>Categories</.h3>
        </div>
        <.button
          link_type="live_patch"
          to={~p"/labels/new"}
          label="New"
          variant="outline"
          icon={:plus}
        />
      </div>
      <ul>
        <li :for={c <- @categories}>
          <.link patch={~p"/labels/#{c}"}>
            <%= c.name %>
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :changeset, Ecto.Changeset, required: true
  attr :form, :any

  def category_form(assigns) do
    ~H"""
    <.form for={@form} phx-change="change_category" phx-submit="submit_category">
      <.field field={@form[:name]} />
      <div class="flex justify-end gap-3">
        <%= if @changeset.data.id == nil do %>
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
            to={~p"/labels/#{@changeset.data}"}
          />
          <.button type="submit" label="Update" icon={:check} />
        <% end %>
      </div>
    </.form>
    """
  end

  attr :category, Category, required: true

  def category_values(assigns) do
    ~H"""
    <ul>
      <li :for={v <- @category.values}>
        <.link patch={~p"/labels/#{@category}/values/#{v}"}>
          <%= v.value %>
        </.link>
      </li>
    </ul>
    """
  end

  def value_form(assigns) do
    ~H"""
    <.form for={@form} phx-change="change_value" phx-submit="submit_value">
      <.field field={@form[:value]} />
      <div class="flex justify-end gap-3">
        <%= if @changeset.data.id == nil do %>
          <.button
            type="button"
            label="Cancel"
            icon={:x_mark}
            link_type="live_patch"
            to={~p"/labels/#{@category}"}
          />
          <.button type="submit" label="Add" icon={:plus} />
        <% else %>
          <.button
            type="button"
            label="Cancel"
            icon={:x_mark}
            link_type="live_patch"
            to={~p"/labels/#{@category}/values/#{@changeset.data}"}
          />
          <.button type="submit" label="Update" icon={:check} />
        <% end %>
      </div>
    </.form>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        current_page: :labels,
        page_title: "Labels",
        category: nil,
        value: nil,
        changeset: nil,
        form: nil
      )
      |> load_categories()

    {:ok, socket}
  end

  defp load_categories(socket) do
    q = from(Filer.Labels.Category, order_by: :name)
    assign(socket, :categories, Filer.Repo.all(q))
  end

  @impl true
  def handle_params(params, _uri, socket) do
    category =
      with {:ok, id_string} <- Map.fetch(params, "id"),
           {id, ""} <- Integer.parse(id_string),
           %Category{} = c <- from(Category, preload: [:values]) |> Filer.Repo.get(id) do
        c
      else
        _ -> nil
      end

    value =
      with {:ok, value_string} <- Map.fetch(params, "value"),
           {id, ""} <- Integer.parse(value_string),
           %Value{} = v <- Filer.Repo.get(Value, id) do
        v
      else
        _ -> nil
      end

    changeset =
      case Map.get(socket.assigns, :live_action) do
        :new_category -> Ecto.Changeset.change(%Category{})
        :edit_category -> Ecto.Changeset.change(category)
        :new_value -> Ecto.Changeset.change(Ecto.build_assoc(category, :values))
        :edit_value -> Ecto.Changeset.change(value)
        _ -> nil
      end

    form =
      case changeset do
        nil -> nil
        _ -> to_form(changeset)
      end

    socket = assign(socket, category: category, value: value, changeset: changeset, form: form)
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket)

  def handle_event("change_category", %{"category" => params}, socket) do
    form = socket.assigns.changeset |> Category.changeset(params) |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit_category", %{"category" => params}, socket) do
    changeset = Category.changeset(socket.assigns.changeset, params)

    result =
      case changeset.data.id do
        nil -> Filer.Repo.insert(changeset)
        _ -> Filer.Repo.update(changeset)
      end

    socket =
      case result do
        {:ok, category} -> socket |> load_categories() |> push_patch(to: ~p"/labels/#{category}")
        {:error, changeset} -> assign(socket, form: to_form(changeset))
      end

    {:noreply, socket}
  end

  def handle_event("delete_category", _, socket) do
    socket =
      case Map.fetch(socket.assigns, :category) do
        {:ok, category} ->
          Filer.Repo.delete(category)
          socket |> load_categories() |> push_patch(to: ~p"/labels")

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("change_value", %{"value" => params}, socket) do
    form = socket.assigns.changeset |> Value.changeset(params) |> to_form()
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit_value", %{"value" => params}, socket) do
    Logger.info("submit_value #{inspect(params)}")
    changeset = Value.changeset(socket.assigns.changeset, params)
    Logger.info("changeset: #{inspect(changeset)}")

    result =
      case changeset.data.id do
        nil ->
          Logger.info("new value")
          Filer.Repo.insert(changeset)

        _ ->
          Logger.info("existing value")
          Filer.Repo.update(changeset)
      end

    socket =
      case result do
        {:ok, value} ->
          Logger.info("inserted successfully #{inspect(value)}")

          socket
          |> push_patch(to: ~p"/labels/#{value.category_id}/values/#{value}")

        {:error, changeset} ->
          Logger.info("failed insert #{inspect(changeset)}")
          assign(socket, form: to_form(changeset))
      end

    {:noreply, socket}
  end

  def handle_event("delete_value", _, socket) do
    socket =
      case socket.assigns.value do
        nil ->
          socket

        value ->
          Filer.Repo.delete(value)
          push_patch(socket, to: ~p"/labels/#{value.category}")
      end

    {:noreply, socket}
  end
end
