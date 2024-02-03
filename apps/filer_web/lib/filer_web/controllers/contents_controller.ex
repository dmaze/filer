defmodule FilerWeb.ContentsController do
  @doc """
  Controllers for content objects.

  """
  use FilerWeb, :controller

  @doc """
  Produce a single-page PNG image of a content object.

  """
  def png(conn, %{"id" => id_string}) do
    with {id, ""} <- Integer.parse(id_string),
         c when is_struct(c) <- Filer.Repo.get(Filer.Files.Content, id),
         path when is_binary(path) <- Filer.Files.any_file_for_content(c),
         {:ok, content} <- File.read(path) do
      task = Task.async(Filer.Render, :to_png, [content, [resolution: 72]])

      case Task.await(task) do
        {:ok, content} ->
          conn
          |> put_resp_content_type("image/png")
          |> send_resp(:ok, content)

        _ ->
          send_resp(conn, :internal_server_error, "Internal Server Error")
      end
    else
      _ -> send_resp(conn, :not_found, "Not Found")
    end
  end
end
