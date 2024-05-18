defmodule Mix.Tasks.Filer.Env do
  @moduledoc """
  Generate a `.env` file.

  This is needed to run the application in Docker Compose.

  By default this reads the existing `.env` file and preserves existing
  secret values.  Specifying `--force` will also regenerate all of the
  secrets.

  This makes an attempt to detect a Minikube environment using the
  `MINIKUBE_ACTIVE_DOCKERD` environment variable, which is set by
  `minikube docker-env`.

  ### Command line options

  * `--postgres-port` - host-accessible port of the PostgreSQL database, defaults to 5432
  * `--filer-port` - host-accessible port of the Filer application, defaults to 4000
  * `--file` - name of the `.env` file, defaults to `.env`
  * `--dry-run` - write the file to stdout instead of overwriting it
  * `--force` - regenerate all options even if they exist

  """
  @shortdoc "Generate a `.env` file"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _args} =
      OptionParser.parse!(args,
        strict: [
          postgres_port: :integer,
          filer_port: :integer,
          force: :boolean,
          dry_run: :boolean,
          file: :string
        ]
      )

    filename = Keyword.get(opts, :file, ".env")

    settings =
      case File.open(filename, [:read, :utf8], &read_settings/1) do
        {:ok, s} ->
          s

        {:error, :enoent} ->
          []

        {:error, reason} ->
          raise File.Error,
            reason: reason,
            action: "read existing file",
            path: filename
      end

    vars = [
      {"POSTGRES_USER", "postgres"},
      {"POSTGRES_DB", db_name()},
      {"POSTGRES_HOST_PORT", Keyword.get(opts, :postgres_port, 5432) |> Integer.to_string()},
      {"FILER_HOST_NAME", docker_ip()},
      {"FILER_HOST_PORT", Keyword.get(opts, :filer_port, 4000) |> Integer.to_string()}
    ]

    settings =
      Enum.reduce(vars, settings, fn {k, v}, s -> update_kvp(s, k, v, true) end)

    secrets = [
      {"POSTGRES_PASSWORD", [dev_password: Mix.env() != :prod]},
      {"GOSSIP_SECRET", []},
      {"RELEASE_COOKIE", []},
      {"SECRET_KEY_BASE", bytes: 48}
    ]

    force = Keyword.get(opts, :force, false)

    settings =
      Enum.reduce(secrets, settings, fn {k, opts}, s -> update_kvp(s, k, secret(opts), force) end)

    if Keyword.get(opts, :dry_run) do
      write_settings(:stdio, settings)
    else
      File.open!(filename, [:write, :utf8], &write_settings(&1, settings))
    end
  end

  defp read_settings(iodev) do
    iodev
    |> IO.stream(:line)
    |> Enum.map(fn s ->
      s |> String.trim_trailing() |> String.split("=", parts: 2) |> List.to_tuple()
    end)
  end

  defp write_settings(iodev, settings) do
    settings |> Stream.map(fn {k, v} -> "#{k}=#{v}" end) |> Enum.each(&IO.puts(iodev, &1))
  end

  @spec update_kvp([{k, v}], k, v, boolean()) :: [{k, v}] when k: any(), v: any()
  defp update_kvp(kvps, key, value, force) do
    replace = fn
      {^key, _} -> {key, value}
      {k, v} -> {k, v}
    end

    cond do
      !Enum.any?(kvps, fn {k, _} -> k == key end) -> kvps ++ [{key, value}]
      force -> Enum.map(kvps, replace)
      true -> kvps
    end
  end

  defp secret(opts) do
    if Keyword.get(opts, :dev_password) do
      "passw0rd"
    else
    bytes = Keyword.get(opts, :bytes, 24)
    :crypto.strong_rand_bytes(bytes) |> Base.encode64(padding: false)
  end
end

  defp db_name() do
    if Mix.env() == :prod do
      "filer"
    else
      "filer_#{Atom.to_string(Mix.env())}"
    end
  end

  defp docker_ip() do
    if System.get_env("MINIKUBE_ACTIVE_DOCKERD") do
      {ip, 0} = System.cmd("minikube", ["ip"])
      ip |> String.trim()
    else
      "localhost"
    end
  end
end
