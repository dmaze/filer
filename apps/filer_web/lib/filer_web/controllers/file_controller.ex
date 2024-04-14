defmodule FilerWeb.FileController do
  use FilerWeb, :controller

  alias Filer.Files
  alias Filer.Files.File

  action_fallback FilerWeb.FallbackController

  def index(conn, %{"path" => path}) do
    files =
      case Files.get_file_by_path(path) do
        nil -> []
        f -> [f]
      end

    render(conn, :index, files: files)
  end

  def index(conn, _params) do
    files = Files.list_files()
    render(conn, :index, files: files)
  end

  def create(conn, %{"file" => file_params}) do
    with {:ok, %File{} = file} <- Files.create_file(file_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/files/#{file}")
      |> render(:show, file: file)
    end
  end

  def show(conn, %{"id" => id}) do
    file = Files.get_file!(id)
    render(conn, :show, file: file)
  end

  def update(conn, %{"id" => id, "file" => file_params}) do
    file = Files.get_file!(id)

    with {:ok, %File{} = file} <- Files.update_file(file, file_params) do
      render(conn, :show, file: file)
    end
  end

  def delete(conn, %{"id" => id}) do
    file = Files.get_file!(id)

    with {:ok, %File{}} <- Files.delete_file(file) do
      send_resp(conn, :no_content, "")
    end
  end
end
