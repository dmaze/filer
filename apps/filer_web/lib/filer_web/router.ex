defmodule FilerWeb.Router do
  use FilerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {FilerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FilerWeb do
    pipe_through :browser

    get "/", PagesController, :index
    live "/files", FilesLive, :index
    live "/files/:id", FilesLive, :show
    live "/files/:id/labels", FilesLive, :labels
    get "/contents/:id/png", ContentsController, :png
    live "/labels", LabelsLive, :index
    live "/labels/new", LabelsLive, :new_category
    live "/labels/:id", LabelsLive, :category
    live "/labels/:id/edit", LabelsLive, :edit_category
    live "/labels/:id/values/new", LabelsLive, :new_value
    live "/labels/:id/values/:value", LabelsLive, :value
    live "/labels/:id/values/:value/edit", LabelsLive, :edit_value
    live "/training", TrainingLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", FilerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:filer_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FilerWeb.Telemetry
    end
  end
end
