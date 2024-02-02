defmodule FilerWeb.LabelsLive do
  use FilerWeb, :live_view
  alias Filer.Labels
  alias Filer.Labels.Category
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
    assign(socket, :categories, Labels.list_categories())
  end

  @impl true
  def handle_params(params, _uri, socket) do
    category = Labels.get_category(Map.get(params, "id")) || Labels.new_category()
    value = Labels.get_value(Map.get(params, "value")) || Labels.new_value(category)
    socket = assign(socket, category: category, value: value)
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket)

  def handle_event("delete_category", _, socket) do
    socket =
      case Map.fetch(socket.assigns, :category) do
        {:ok, category} ->
          _ = Labels.delete_category(category)
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
          _ = Labels.delete_value(value)
          push_patch(socket, to: ~p"/labels/#{value.category_id}")
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
