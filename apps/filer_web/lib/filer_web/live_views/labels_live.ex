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
        <%= if @live_action == :new_category || @live_action == :edit_category do %>
          <.edit_category category={@category} on_change={&send(self(), {:changed_category, &1})} />
        <% else %>
          <div :if={@category.id} class="flex gap-2">
            <.h4 class="grow"><%= @category.name %></.h4>
            <%= if @live_action == :category || @live_action == :value do %>
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
        <%= if not(is_nil(@category.id)) do %>
          <%= if @live_action == :new_value || @live_action == :edit_value do %>
            <.edit_value value={@value} />
          <% else %>
            <div :if={@value} class="flex gap-2">
              <.h5 class="grow"><%= @value.value %></.h5>
              <%= if @live_action == :value do %>
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

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        current_page: :labels,
        page_title: "Labels",
        category: nil,
        value: nil
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
        _ -> %Category{}
      end

    value =
      with {:ok, value_string} <- Map.fetch(params, "value"),
           {id, ""} <- Integer.parse(value_string),
           %Value{} = v <- Filer.Repo.get(Value, id) do
        v
      else
        _ ->
          case category.id do
            nil -> nil
            _ -> Ecto.build_assoc(category, :values)
          end
      end

    socket = assign(socket, category: category, value: value)
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket)

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

  @impl true
  def handle_info(message, socket)

  def handle_info({:changed_category, _category}, socket) do
    socket = load_categories(socket)
    {:noreply, socket}
  end
end
