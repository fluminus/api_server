defmodule Credential do
  defstruct username: nil, password: nil
end

defmodule Authorization do
  defstruct idsrv: nil, jwt: nil
end

defmodule PeriodicTask do
  use GenServer

  @fetch_interval 3000
  @limit 1

  def init(opts) do
    case opts do
      %Authorization{idsrv: _idsrv, jwt: _jwt} ->
        Process.send_after(self(), :tick, @fetch_interval)
        {:ok, opts}
      _ -> :wrong_argument
    end
  end

  def handle_info(:tick, state) do
    auth = %Fluminus.Authorization{
      client: %Fluminus.HTTPClient{
        cookies: %{"idsrv" => state.idsrv}
      },
      jwt: state.jwt
    }
    case Fluminus.API.api(auth, "/notification?limit=#{@limit}&sortby=recordDate%20desc") do
      {:ok, resp} ->
        IO.inspect(resp)
        time =
          DateTime.utc_now()
          |> DateTime.to_time()
          |> Time.to_iso8601()
        IO.puts("Updated at #{time}")
        Process.send_after(self(), :tick, @fetch_interval)
        {:noreply, state}
      _ -> :error
    end
  end
end

defmodule FluminusServerWeb.DefaultController do
  use FluminusServerWeb, :controller

  def index(conn, _params) do
    text(conn, "connected!")
  end

  @spec activate_pn(Plug.Conn.t(), any) :: Plug.Conn.t()
  def activate_pn(conn, params) do
    case params do
      %{"idsrv" => idsrv, "jwt" => jwt} ->
        auth = %Fluminus.Authorization{
              client: %Fluminus.HTTPClient{
                cookies: %{"idsrv" => idsrv}
              },
              jwt: jwt
            }
        case Fluminus.Authorization.renew_jwt(auth) do
          {:ok, renewed_auth} ->
            case Fluminus.API.api(renewed_auth, "/user/Profile") do
              {:ok, map} ->
                alias Ecto.Adapters.SQL
                query_string = "INSERT INTO pn VALUES (\"#{map["userID"]}\", \"#{renewed_auth.client.cookies["idsrv"]}\", \"#{renewed_auth.jwt}\", curtime())"
                SQL.query(FluminusServer.Repo, query_string, [])
                GenServer.start(PeriodicTask, %Authorization{idsrv: renewed_auth.client.cookies["idsrv"], jwt: renewed_auth.jwt})
                conn |> send_resp(201, "Enabled push notification for " <> map["userID"])
              _ -> conn |> send_resp(500, "")
            end
          {:error, :invalid_authorization} -> conn |> send_resp(400, "Invalid credentials")
          _ -> conn |> send_resp(500, "")
        end
      _ -> conn |> send_resp(400, "Please provide both idsrv and jwt as strings")
    end
  end
end
