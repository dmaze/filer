defmodule Filer.PromEx do
  @moduledoc """
  `PromEx` configuration to publish metrics.

  """

  use PromEx, otp_app: :filer

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # PromEx built in plugins
      Plugins.Application,
      Plugins.Beam
      # {Plugins.Phoenix, router: FilerWeb.Router, endpoint: FilerWeb.Endpoint},
      # Plugins.Ecto,
      # Plugins.Oban,
      # Plugins.PhoenixLiveView,
      # Plugins.Absinthe,
      # Plugins.Broadway,

      # Add your own PromEx metrics plugins
      # Filer.Users.PromExPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "Prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      # PromEx built in Grafana dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"}
      # {:prom_ex, "phoenix.json"},
      # {:prom_ex, "ecto.json"},
      # {:prom_ex, "oban.json"},
      # {:prom_ex, "phoenix_live_view.json"},
      # {:prom_ex, "absinthe.json"},
      # {:prom_ex, "broadway.json"},

      # Add your dashboard definitions here with the format: {:otp_app, "path_in_priv"}
      # {:filer, "/grafana_dashboards/user_metrics.json"}
    ]
  end
end
