defmodule FilerWeb.PagesController do
  @moduledoc """
  Controllers for arbitrary loose pages.

  """
  use FilerWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/files")
  end
end
