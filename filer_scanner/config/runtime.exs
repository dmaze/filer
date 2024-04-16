import Config

config :filer_scanner,
  url: System.get_env("FILER_URL", "http://localhost:4000/"),
  path: System.get_env("FILER_PATH", Path.join(File.cwd!(), "data")),
  continuous: System.get_env("FILER_CONTINUOUS", "false")
