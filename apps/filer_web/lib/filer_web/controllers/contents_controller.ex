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
         {:ok, content} <- Filer.Store.get({c.hash, :png, :res72}) do
      conn
      |> put_resp_content_type("image/png")
      |> send_resp(:ok, content)
    else
      _ -> send_resp(conn, :not_found, "Not Found")
    end
  end
end
