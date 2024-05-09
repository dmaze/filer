defmodule FilerWeb.ContentController do
  use FilerWeb, :controller

  alias Filer.Files
  alias Filer.Files.Content

  action_fallback FilerWeb.FallbackController

  plug :content_type, ["application/pdf"] when action in [:create]

  def index(conn, %{"hash" => hash}) do
    contents =
      case Files.get_content_by_hash(hash) do
        nil -> []
        c -> [c]
      end

    render(conn, :index, contents: contents)
  end

  def index(conn, _params) do
    contents = Files.list_contents()
    render(conn, :index, contents: contents)
  end

  def create(conn, _params) do
    {:ok, body, conn} = read_entire_body(conn, [])
    hash = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
    :ok = FilerStore.put({hash, :pdf}, IO.iodata_to_binary(body))
    content = Files.content_by_hash(hash)

    conn
    |> put_status(:created)
    |> put_resp_header("location", url(~p"/api/contents/#{content}"))
    |> render(:show, content: content)
  end

  def content_type(conn, types) do
    content_types =
      Plug.Conn.get_req_header(conn, "content-type") |> Enum.map(&Plug.Conn.Utils.content_type/1)

    accepted_types = Enum.map(types, &Plug.Conn.Utils.content_type/1)
    is_ok = fn {:ok, at, ast, _}, {:ok, ct, cst, _} -> at == ct && ast == cst end

    if Enum.any?(accepted_types, fn at ->
         Enum.any?(content_types, &is_ok.(at, &1))
       end) do
      conn
    else
      raise %Plug.Parsers.UnsupportedMediaTypeError{}
    end
  end

  @spec read_entire_body(Plug.Conn.t(), iolist()) ::
          {:ok, iolist(), Plug.Conn.t()} | {:error, term()}
  defp read_entire_body(conn, rev_prefix) do
    case Plug.Conn.read_body(conn) do
      {:ok, content, conn} ->
        {:ok, Enum.reverse([content | rev_prefix]), conn}

      {:more, content, conn} ->
        read_entire_body(conn, [content | rev_prefix])

      {:error, why} ->
        {:error, why}
    end
  end

  def show(conn, %{"id" => id}) do
    content = Files.get_content!(id)
    render(conn, :show, content: content)
  end

  def show_pdf(conn, %{"content_id" => id}) do
    content = Files.get_content!(id)

    case FilerStore.get({content.hash, :pdf}) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> send_resp(:ok, content)

      _ ->
        {:error, :not_found}
    end
  end

  def show_png(conn, %{"content_id" => id}) do
    content = Files.get_content!(id)

    case FilerStore.get({content.hash, :png, :res72}) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("image/png")
        |> send_resp(:ok, content)

      _ ->
        {:error, :not_found}
    end
  end

  def update(conn, %{"id" => id, "content" => content_params}) do
    content = Files.get_content!(id)

    with {:ok, %Content{} = content} <- Files.update_content(content, content_params) do
      render(conn, :show, content: content)
    end
  end

  def delete(conn, %{"id" => id}) do
    content = Files.get_content!(id)

    with {:ok, %Content{}} <- Files.delete_content(content) do
      send_resp(conn, :no_content, "")
    end
  end
end
