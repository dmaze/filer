defmodule FilerWeb.FilesLive do
  use FilerWeb, :live_view
  import Ecto.Query, only: [from: 2]

  ## HTML OUTPUT

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex max-w-full">
      <div class="p-2 max-w-96 w-1/4 border rounded-md"><.listing files={@files} /></div>
      <div class="p-2 grow"><.details file={@file} /></div>
    </div>
    """
  end

  attr :files, :list, required: true

  def listing(assigns) do
    ~H"""
    <ul role="list">
      <.entry :for={f <- @files} file={f} />
    </ul>
    """
  end

  attr :file, Filer.Files.File, required: true

  def entry(assigns) do
    f = assigns[:file]

    assigns =
      assigns
      |> assign(:dir, Path.dirname(f.path))
      |> assign(:file, Path.basename(f.path))
      |> assign(:id, f.id)

    ~H"""
    <li>
      <.link patch={~p"/files/#{@id}"} class="flex">
        <span class="flex-initial w-64 truncate" dir="rtl"><%= @dir %></span>
        <span class="flex-auto truncate"><%= @file %></span>
      </.link>
    </li>
    """
  end

  attr :file, Filer.Files.File, default: nil

  def details(assigns) do
    ~H"""
    <%= if @file == nil do %>
      <div>No file selected</div>
    <% else %>
      <div class="truncate"><%= @file.path %></div>
      <.content content={@file.content} />
    <% end %>
    """
  end

  attr :content, Filer.Files.Content, required: true

  def content(assigns) do
    ~H"""
    <div><img src={~p"/contents/#{@content.id}/png"} /></div>
    """
  end

  ## ASSIGNS

  @impl true
  def mount(_params, _session, socket) do
    q = from(Filer.Files.File, order_by: :path)

    socket =
      socket
      |> assign(:current_page, :files)
      |> assign(:page_title, "Files")
      |> assign(:files, Filer.Repo.all(q))
      |> assign(:file, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    maybe_f =
      with {:ok, id_string} <- Map.fetch(params, "id"),
           {id, ""} <- Integer.parse(id_string),
           f when is_struct(f) <-
             Filer.Repo.get(Filer.Files.File |> Ecto.Query.preload(:content), id) do
        {:ok, f}
      end

    socket =
      case maybe_f do
        {:ok, f} -> socket |> assign(:file, f) |> assign(:page_title, Path.basename(f.path))
        _ -> socket
      end

    {:noreply, socket}
  end
end
