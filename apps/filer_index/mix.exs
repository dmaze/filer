defmodule FilerIndex.MixProject do
  use Mix.Project

  def project do
    [
      app: :filer_index,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {FilerIndex.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:filer, in_umbrella: true},
      {:filer_store, in_umbrella: true},
      # phoenix_live_reload has a similar constraint
      {:file_system, "~> 0.2.8"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
