defmodule FluminusServer.Repo do
  use Ecto.Repo,
    otp_app: :fluminus_server,
    adapter: Ecto.Adapters.MySQL
end
