defmodule FilerWeb.TrainingLive do
  use FilerWeb, :live_view

  # Maybe eventually there will be more here.

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @running? do %>
        <.button label="Running" disabled loading />
      <% else %>
        <.button label="Start" icon={:play} phx-click="start" />
      <% end %>
      <%= if @state do %>
        <.h3>Epoch</.h3>
        <.progress
          size="xl"
          value={@state.epoch + 1}
          max={@state.max_epoch}
          label={"#{@state.epoch + 1} / #{@state.max_epoch}"}
        />
        <%= if @state.max_iteration <= 0 do %>
          <%= if @state.iteration > 0 do %>
            <.h4>Iteration <%= @state.iteration %></.h4>
          <% end %>
        <% else %>
          <.h4>Iteration</.h4>
          <.progress
            size="xl"
            value={@state.iteration + 1}
            max={@state.max_iteration}
            label={"#{@state.iteration + 1} / #{@state.max_iteration}"}
          />
        <% end %>
        <.h3>Metrics</.h3>
        <div class="grid grid-cols-2 gap-4">
          <.metric_card :for={{k, v} <- @state.metrics} key={k} value={v} />
        </div>
      <% end %>
    </div>
    """
  end

  def metric_card(assigns) do
    percent = round(assigns.value * 100)

    display =
      case assigns.key do
        k when k in ["accuracy", "precision", "recall"] ->
          :erlang.float_to_binary(assigns.value * 100, decimals: 1) <> "%"

        _ ->
          :erlang.float_to_binary(assigns.value, decimals: 3)
      end

    color =
      case assigns.key do
        "accuracy" -> "success"
        "precision" -> "success"
        "recall" -> "success"
        "loss" -> "warning"
        _ -> "info"
      end

    assigns = assigns |> assign(percent: percent, display: display, color: color)

    ~H"""
    <.card>
      <.card_content heading={@key}>
        <.progress color={@color} size="xl" value={@percent} max={100} label={@display} />
      </.card_content>
    </.card>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :ok = Filer.PubSub.subscribe_trainer()
    end

    socket =
      assign(socket,
        current_page: :training,
        page_title: "Training",
        running?: Filer.Trainer.training?(),
        state: Filer.Trainer.trainer_state()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("start", _, socket) do
    Filer.Trainer.train()
    {:noreply, socket}
  end

  @impl true
  def handle_info(:trainer_start, socket) do
    socket = assign(socket, :running?, true)
    {:noreply, socket}
  end

  def handle_info({:trainer_complete, _}, socket) do
    socket = assign(socket, :running?, false)
    {:noreply, socket}
  end

  def handle_info({:trainer_failed, _}, socket) do
    socket = assign(socket, :running?, false)
    {:noreply, socket}
  end

  def handle_info({:trainer_state, state}, socket) do
    socket = assign(socket, :state, state)
    {:noreply, socket}
  end
end
