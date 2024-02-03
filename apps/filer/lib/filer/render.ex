defmodule Filer.Render do
  @moduledoc """
  Render PDF files to other formats.

  """

  @typedoc """
  Options for rendering PNG.

  `:resolution` -- resolution in dots per inch, defaults to 72

  """
  @type option() :: {:resolution, pos_integer()}

  @doc """
  Get a command and options to run Ghostscript.

  Normally used inside to_png/2, but these are also the options needed
  to run it asynchronously via a Port.

  Returns `:not_found` if a `gs` binary can't be found; otherwise,
  returns a pair of the command string with an absolute path and the
  corresponding command-line options.

  """
  @spec gs_command(String.t(), [option()]) :: {:ok, String.t(), [String.t()]} | :not_found
  def gs_command(path, opts \\ []) do
    resolution = Keyword.get(opts, :resolution, 72)

    case System.find_executable("gs") do
      nil ->
        :not_found

      command ->
        {:ok, command,
         [
           "-q",
           "-dBATCH",
           "-dNOPAUSE",
           "-r#{resolution}",
           "-dLastPage=1",
           "-sDEVICE=png16m",
           "-sOutputFile=-",
           path
         ]}
    end
  end

  @doc """
  Convert a PDF-format binary string to PNG.

  On success, returns the PNG content as a binary string.  If executing
  Ghostscript fails, returns its error code; if a `gs` binary can't be
  found on the system, returns `:not_found`.

  This creates a temporary file that will be deleted at process exit.
  If this is called somewhere other than a relatively short-lived process,
  it is recommended to run it in a `Task`.

  """
  @spec to_png(binary(), [option()]) :: {:ok, binary()} | {:error, integer()} | :not_found
  def to_png(content, opts \\ []) do
    # We'd love to run `gs ... -` and pipe content to its stdin.
    # There's a long-standing Erlang-level issue that you can't separately
    # close a port's input and output, though: if you close the port, it sends
    # EOF, but also stops accepting responses.  The canonical example is
    # invoking wc(1) but it applies here too.
    path = Briefly.create!(prefix: "filer", extname: "pdf")
    File.write!(path, content)

    case gs_command(path, opts) do
      {:ok, command, args} ->
        case System.cmd(command, args) do
          {result, 0} -> {:ok, result}
          {_, code} -> {:error, code}
        end

      :not_found ->
        :not_found
    end
  end
end
