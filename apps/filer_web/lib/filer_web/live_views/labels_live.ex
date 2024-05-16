defmodule FilerWeb.LabelsLive do
  use FilerWeb, :live_view
  alias Filer.Labels
  alias Filer.Labels.{Category, Value}
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <.category_list categories={@categories} editable={@changeset == nil} changeset={@changeset} />
    """
  end

  attr :categories, :list, required: true
  attr :editable, :boolean, default: true
  attr :changeset, Ecto.Changeset, required: false, default: nil

  def category_list(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4">
      <%= for c <- @categories do %>
        <%= if changeset_is?(@changeset, c) do %>
          <.edit_category_card changeset={@changeset} />
        <% else %>
          <.category_card category={c} editable={@editable} changeset={@changeset} />
        <% end %>
      <% end %>
      <%= if changeset_is?(@changeset, %Category{id: nil}) do %>
        <.edit_category_card changeset={@changeset} />
      <% end %>
      <%= if @editable do %>
        <.icon_button
          class="border shadow-lg place-self-center"
          size="xl"
          tooltip="New"
          link_type="live_patch"
          to={~p"/labels/new"}
        >
          <Heroicons.plus />
        </.icon_button>
      <% end %>
    </div>
    """
  end

  attr :category, Category, required: true
  attr :editable, :boolean, default: true
  attr :changeset, Ecto.Changeset, required: false, default: nil

  def category_card(assigns) do
    # Since we want to do things like put a text box in the card title, we
    # can't use the Petal <.card/>.
    ~H"""
    <.min_card>
      <.edit_controls editable={@editable}>
        <div class="text-lg font-bold pb-2"><%= @category.name %></div>
        <:buttons>
          <.icon_button
            size="xs"
            tooltip="Edit"
            link_type="live_patch"
            to={~p"/labels/#{@category}/edit"}
          >
            <Heroicons.pencil />
          </.icon_button>
          <.icon_button
            size="xs"
            tooltip="New Value"
            link_type="live_patch"
            to={~p"/labels/#{@category}/values/new"}
          >
            <Heroicons.plus />
          </.icon_button>
          <.icon_button
            size="xs"
            tooltip="Delete"
            phx-click="delete_category"
            phx-value-id={@category.id}
          >
            <Heroicons.trash />
          </.icon_button>
        </:buttons>
      </.edit_controls>
      <%= if Ecto.assoc_loaded?(@category.values) do %>
        <.values_list category={@category} editable={@editable} changeset={@changeset} />
      <% end %>
    </.min_card>
    """
  end

  attr :changeset, Ecto.Changeset, required: true

  def edit_category_card(assigns) do
    assigns =
      assigns |> assign(form: to_form(assigns.changeset), category: assigns.changeset.data)

    ~H"""
    <.min_card>
      <.form for={@form} phx-change="change_category" phx-submit="submit_category">
        <.edit_controls editing={true}>
          <.field field={@form[:name]} label_class="hidden" />
          <:buttons>
            <.icon_button size="xs" tooltip={if @category.id, do: "Update", else: "Create"}>
              <Heroicons.check />
            </.icon_button>
            <.icon_button size="xs" tooltip="Cancel" link_type="live_patch" to={~p"/labels"}>
              <Heroicons.x_mark />
            </.icon_button>
          </:buttons>
        </.edit_controls>
      </.form>
      <%= if Ecto.assoc_loaded?(@category.values) do %>
        <.values_list category={@category} editable={false} />
      <% end %>
    </.min_card>
    """
  end

  attr :category, Category, required: true
  attr :editable, :boolean, default: true
  attr :changeset, Ecto.Changeset, required: false, default: nil

  def values_list(assigns) do
    ~H"""
    <%= for v <- @category.values do %>
      <%= if changeset_is?(@changeset, v) do %>
        <.edit_value_item changeset={@changeset} />
      <% else %>
        <.value_item value={v} editable={@editable} />
      <% end %>
    <% end %>
    <%= if changeset_is?(@changeset, %Value{id: nil}) && @changeset.data.category_id == @category.id do %>
      <.edit_value_item changeset={@changeset} />
    <% end %>
    """
  end

  attr :value, Value, required: true
  attr :editable, :boolean, default: true

  def value_item(assigns) do
    ~H"""
    <.edit_controls editable={@editable}>
      <%= @value.value %>
      <:buttons>
        <.icon_button
          size="xs"
          tooltip="Edit"
          link_type="live_patch"
          to={~p"/labels/#{@value.category_id}/values/#{@value}/edit"}
        >
          <Heroicons.pencil />
        </.icon_button>
        <.icon_button size="xs" tooltip="Delete" phx-click="delete_value" phx-value-id={@value.id}>
          <Heroicons.trash />
        </.icon_button>
      </:buttons>
    </.edit_controls>
    """
  end

  attr :changeset, Ecto.Changeset, required: true

  def edit_value_item(assigns) do
    assigns = assigns |> assign(form: to_form(assigns.changeset), value: assigns.changeset.data)

    ~H"""
    <.form for={@form} phx-change="change_value" phx-submit="submit_value">
      <.edit_controls editing={true}>
        <.field field={@form[:value]} label_class="hidden" />
        <:buttons>
          <.icon_button size="xs" tooltip={if @value.id, do: "Update", else: "Create"}>
            <Heroicons.check />
          </.icon_button>
          <.icon_button size="xs" tooltip="Cancel" link_type="live_patch" to={~p"/labels"}>
            <Heroicons.x_mark />
          </.icon_button>
        </:buttons>
      </.edit_controls>
    </.form>
    """
  end

  attr :editable, :boolean, default: true
  attr :editing, :boolean, default: false
  slot :inner_block, required: true
  slot :buttons, required: true

  def edit_controls(assigns) do
    button_class =
      cond do
        assigns.editing -> ""
        assigns.editable -> "invisible group-hover:visible"
        true -> "invisible"
      end

    assigns = assigns |> assign(:button_class, button_class)

    ~H"""
    <div class="flex group">
      <div class="grow">
        <%= render_slot(@inner_block) %>
      </div>
      <div class={@button_class}>
        <%= render_slot(@buttons) %>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true

  def min_card(assigns) do
    ~H"""
    <div class="border rounded-lg shadow-lg p-4">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def changeset_is?(changeset, struct)
  def changeset_is?(%{data: %s{id: id}}, %s{id: id}), do: true
  def changeset_is?(_, _), do: false

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        current_page: :labels,
        page_title: "Labels",
        category: nil,
        value: nil,
        changeset: nil
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

    changeset =
      case socket.assigns.live_action do
        :new_category -> Ecto.Changeset.change(category)
        :edit_category -> Ecto.Changeset.change(category)
        :new_value -> Ecto.Changeset.change(value)
        :edit_value -> Ecto.Changeset.change(value)
        _ -> nil
      end

    socket = assign(socket, changeset: changeset)
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket)

  def handle_event("delete_category", %{"id" => id}, socket) do
    socket =
      with category when not is_nil(category) <- Labels.get_category(id),
           {:ok, _} <- Labels.delete_category(category) do
        socket |> load_categories()
      else
        _ -> socket
      end

    {:noreply, socket}
  end

  def handle_event("change_category", %{"category" => params}, socket) do
    changeset = socket.assigns.changeset |> Category.changeset(params)
    socket = socket |> assign(:changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("submit_category", %{"category" => params}, socket) do
    changeset = socket.assigns.changeset |> Category.changeset(params)

    result =
      case changeset.data.id do
        nil -> Filer.Repo.insert(changeset)
        _ -> Filer.Repo.update(changeset)
      end

    socket =
      case result do
        {:ok, _category} ->
          socket |> load_categories() |> push_patch(to: ~p"/labels")

        {:error, changeset} ->
          socket |> assign(changeset: changeset)
      end

    {:noreply, socket}
  end

  def handle_event("delete_value", %{"id" => id}, socket) do
    socket =
      with value when not is_nil(value) <- Labels.get_value(id),
           {:ok, _} <- Labels.delete_value(value) do
        socket |> load_categories()
      else
        _ -> socket
      end

    {:noreply, socket}
  end

  def handle_event("change_value", %{"value" => params}, socket) do
    changeset = socket.assigns.changeset |> Value.changeset(params)
    socket = socket |> assign(:changeset, changeset)
    {:noreply, socket}
  end

  def handle_event("submit_value", %{"value" => params}, socket) do
    changeset = socket.assigns.changeset |> Value.changeset(params)

    result =
      case changeset.data.id do
        nil -> Filer.Repo.insert(changeset)
        _ -> Filer.Repo.update(changeset)
      end

    socket =
      case result do
        {:ok, _value} ->
          socket |> load_categories() |> push_patch(to: ~p"/labels")

        {:error, changeset} ->
          socket |> assign(changeset: changeset)
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
