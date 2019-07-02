defmodule FluminusServerWeb.Router do
  use FluminusServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FluminusServerWeb do
    pipe_through :api
    get "/get_jwt", DefaultController, :get_jwt
    post "/activate_pn", DefaultController, :activate_pn
  end
end
