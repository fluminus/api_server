defmodule FluminusServerWeb.Router do
  use FluminusServerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", FluminusServerWeb do
    pipe_through :api
    post "/activate_pn", DefaultController, :activate_pn
    delete "/deactivate_pn", DefaultController, :deactivate_pn
  end
end
