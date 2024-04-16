defmodule FilerScanner.Api do
  @moduledoc """
  Interface to the filer HTTP API.

  HTTP GET requests return maps of parsed JSON, there is not currently
  more abstraction around the returns.

  """
  defstruct [:req]

  @type t() :: %__MODULE__{req: Req.Request.t()}

  @doc """
  Create a new API wrapper.

  It can be created with a URL string, or with a base `Req` request
  object.

  """
  @spec new(Req.Request.t() | Req.url()) :: t()
  def new(%Req.Request{} = req) do
    %__MODULE__{req: req}
  end

  def new(url) do
    %__MODULE__{req: Req.new(base_url: url)}
  end

  @spec list_contents_by_hash(t(), String.t()) :: Req.Response.t()
  def list_contents_by_hash(api, hash)

  def list_contents_by_hash(%{req: req}, hash) do
    Req.get!(req, url: "/api/contents", params: [hash: hash])
  end

  @spec create_content(t(), binary()) :: Req.Response.t()
  def create_content(api, body)

  def create_content(%{req: req}, body) do
    Req.post!(req, url: "/api/contents", headers: [content_type: "application/pdf"], body: body)
  end

  @doc """
  List all of the known files.

  The response should contain a single key `data`, which is a list of file
  objects with `id` and `path`.

  """
  @spec list_files(t()) :: Req.Response.t()
  def list_files(api)

  def list_files(%{req: req}) do
    Req.get!(req, url: "/api/files")
  end

  @doc """
  List files that have exactly a given path.

  The response should contain a single key `data`, which is a list of file
  objects with `id` and `path`.  There should be either zero or one object
  in the list.

  """
  @spec list_files_by_path(t(), String.t()) :: Req.Response.t()
  def list_files_by_path(api, path)

  def list_files_by_path(%{req: req}, path) do
    Req.get!(req, url: "/api/files", params: [path: path])
  end

  @doc """
  Create a file.

  """
  @spec create_file(t(), String.t(), integer()) :: Req.Response.t()
  def create_file(api, path, content_id)

  def create_file(%{req: req}, path, content_id) do
    Req.post!(req,
      url: "/api/files",
      json: %{"file" => %{"path" => path, "content_id" => content_id}}
    )
  end

  @doc """
  Change the content associated with an existing file.

  """
  @spec change_file_content(t(), integer(), integer()) :: Req.Response.t()
  def change_file_content(api, id, content_id)

  def change_file_content(%{req: req}, id, content_id) do
    Req.patch!(req,
      url: "/api/files/:id",
      path_params: [id: id],
      json: %{"file" => %{"content_id" => content_id}}
    )
  end

  @doc """
  Delete a single file by ID.

  """
  @spec delete_file(t(), integer()) :: Req.Response.t()
  def delete_file(api, id)

  def delete_file(%{req: req}, id) do
    Req.delete!(req, url: "/api/files/:id", path_params: [id: id])
  end
end
