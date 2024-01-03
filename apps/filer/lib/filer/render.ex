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
  Convert a PDF file to PNG.

  On success, returns the PNG content as a binary string.  If executing
  Ghostscript fails, returns its error code; if a `gs` binary can't be
  found on the system, returns `:not_found`.

  """
  @spec to_png(String.t(), [option()]) :: {:ok, binary()} | {:error, integer()} | :not_found
  def to_png(path, opts \\ []) do
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
