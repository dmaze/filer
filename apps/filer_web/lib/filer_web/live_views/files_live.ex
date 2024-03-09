defmodule FilerWeb.FilesLive do
  use FilerWeb, :live_view

  ## HTML OUTPUT

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex max-w-full h-full">
      <div class="p-2 max-w-96 w-1/4 h-full"><.listing files={@files} /></div>
      <div class="p-2 grow h-full">
        <.details file={@file} live_action={@live_action} />
      </div>
    </div>
    """
  end

  attr :files, :list, required: true

  def listing(assigns) do
    ~H"""
    <ul role="list" class="border rounded-md overflow-y-scroll h-full p-2">
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
  attr :live_action, :atom, required: true

  def details(assigns) do
    ~H"""
    <%= if @file == nil do %>
      <div>No file selected</div>
    <% else %>
      <div class="flex">
        <div class="truncate grow"><%= @file.path %></div>
        <.button
          label="Labels"
          icon={:tag}
          link_type="live_patch"
          to={if @live_action == :labels, do: ~p"/files/#{@file}", else: ~p"/files/#{@file}/labels"}
          variant={if @live_action == :labels, do: "inverted", else: nil}
        />
      </div>
      <.content_labels :if={@live_action == :labels} content={@file.content} />
      <.content_inferred labels={@file.content.inferences} />
      <.content content={@file.content} />
    <% end %>
    """
  end

  attr :labels, :list, required: true

  def content_inferred(assigns) do
    ~H"""
    <div>
      <b>Labels:</b>
      <%= if @labels != [] do %>
        <%= Enum.map_join(@labels, ", ", & &1.value) %>
      <% else %>
        (none)
      <% end %>
    </div>
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
    socket =
      socket
      |> assign(:current_page, :files)
      |> assign(:page_title, "Files")
      |> assign(:files, Filer.Files.list_files())
      |> assign(:file, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      with {:ok, id} <- Map.fetch(params, "id"),
           f when not is_nil(f) <- Filer.Files.get_file(id) do
        socket |> assign(:file, f) |> assign(:page_title, Path.basename(f.path))
      else
        _ -> socket
      end

    {:noreply, socket}
  end
end
