defmodule FluminusServerWeb.Router do
  use FluminusServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/api", FluminusServerWeb do
    pipe_through :api
    post "/activate_pn", DefaultController, :activate_pn
    delete "/deactivate_pn", DefaultController, :deactivate_pn
  end

  scope "/", FluminusServerWeb do
    pipe_through :browser
    get "/", DefaultController, :index
  end
end
