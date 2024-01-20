defmodule FilerWeb.LabelsLive do
  use FilerWeb, :live_view
  import Ecto.Query, only: [from: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-2">
      <.category_list categories={@categories} />
      <.category_view category={@category} />
    </div>
    """
  end

  attr :categories, :list

  def category_list(assigns) do
    ~H"""
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
        <.link patch={~p"/labels/#{c.id}"}>
          <%= c.name %>
        </.link>
      </li>
    </ul>
    """
  end

  def category_view(assigns) do
    ~H"""
    <div />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    q = from(Filer.Labels.Category, order_by: :name)

    socket =
      socket
      |> assign(:current_page, :labels)
      |> assign(:page_title, "Labels")
      |> assign(:categories, Filer.Repo.all(q))
      |> assign(:category, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket)

  def handle_params(%{"id" => id_string} = params, uri, socket) do
    socket =
      with {id, ""} <- Integer.parse(id_string),
           c when is_struct(c) <-
             Filer.Repo.get(Filer.Files.Categories |> Ecto.Query.preload(:values), id) do
        socket |> assign(:category, c) |> assign(:page_title, "Labels: #{c.name}")
      else
        _ -> socket
      end

    Map.delete(params, "id") |> handle_params(uri, socket)
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end
end
