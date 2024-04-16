defmodule FilerScanner.MixProject do
  use Mix.Project

  def project do
    [
      app: :filer_scanner,
      version: "0.1.0",
      build_path: "../_build",
      deps_path: "../deps",
      lockfile: "../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {FilerScanner.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4"},
      {:file_system, ">= 0.2.8 and < 2.0.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
