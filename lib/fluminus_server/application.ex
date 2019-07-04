defmodule FluminusServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  defp initialization() do
    Logger.info("Initializing...")
    query_string = "SELECT * FROM pn"
    alias Ecto.Adapters.SQL
    case SQL.query(FluminusServer.Repo, query_string, []) do
      {:ok, %Mariaex.Result{ columns: _, connection_id: _, last_insert_id: _, num_rows: _, rows: users}} ->
        Enum.each(users, fn row ->
          user_id = Enum.at(row, 0)
          idsrv = Enum.at(row, 1)
          jwt = Enum.at(row, 2)
          GenServer.start(PeriodicTask, %Authorization{
            idsrv: idsrv,
            jwt: jwt,
            user_id: user_id
          })
        end)
        Logger.info("Initialized!")
      _ -> :error
    end
  end

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      FluminusServer.Repo,
      # Start the endpoint when the application starts
      FluminusServerWeb.Endpoint
      # Starts a worker by calling: FluminusServer.Worker.start_link(arg)
      # {FluminusServer.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FluminusServer.Supervisor]
    return = Supervisor.start_link(children, opts)
    initialization()
    return
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FluminusServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
