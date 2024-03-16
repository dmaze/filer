# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :filer,
  ecto_repos: [Filer.Repo]

config :filer_web,
  ecto_repos: [Filer.Repo],
  generators: [context_app: :filer]

# Configure the job queue
config :filer_index, Oban,
  repo: Filer.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 1800},
    Oban.Plugins.Reindexer,
    FilerIndex.Plugins.Prerender,
    FilerIndex.Plugins.Score
  ],
  queues: [render: 1, score: 1]

# Configures the endpoint
config :filer_web, FilerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: FilerWeb.ErrorHTML, json: FilerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Filer.PubSub,
  live_view: [signing_salt: "Puc3ZBs3"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/filer_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.1",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/filer_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use EXLA for accelerated numerical computation
config :nx, :default_backend, EXLA.Backend
config :nx, :default_defn_options, [compiler: EXLA]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
