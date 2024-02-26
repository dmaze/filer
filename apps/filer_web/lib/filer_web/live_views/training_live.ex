defmodule FilerWeb.TrainingLive do
  use FilerWeb, :live_view

  # Maybe eventually there will be more here.

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.button label="Start" icon={:play} phx-click="start" />
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, current_page: :training, page_title: "Training")
    {:ok, socket}
  end

  @impl true
  def handle_event("start", _, socket) do
    FilerIndex.Trainer.train(FilerIndex.Trainer)
    {:noreply, socket}
  end
end
