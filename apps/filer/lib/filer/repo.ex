defmodule Filer.Repo do
  use Ecto.Repo,
    otp_app: :filer,
    adapter: Ecto.Adapters.Postgres
end
