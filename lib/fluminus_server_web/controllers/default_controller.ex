alias Ecto.Adapters.SQL

defmodule Credential do
  defstruct username: nil, password: nil
end

defmodule Authorization do
  defstruct idsrv: nil, jwt: nil, user_id: nil
end

defmodule PeriodicTask do
  use GenServer

  require Logger

  @fetch_interval 5000
  @limit 1
  @renew_count 20

  def init(opts) do
    case opts do
      %Authorization{idsrv: _idsrv, jwt: _jwt} ->
        Process.send_after(self(), :tick, @fetch_interval)
        {:ok, %{auth: opts, count: 0}}

      _ ->
        :wrong_argument
    end
  end

  def handle_info(:tick, state) do
    query_string =
      "SELECT COUNT(*) FROM pn WHERE user_id=\"#{state.auth.user_id}\""
    {:ok, %Mariaex.Result{
      columns: _,
      connection_id: _,
      last_insert_id: _,
      num_rows: _,
      rows: rows
    }} = SQL.query(FluminusServer.Repo, query_string, [])
    rows = Enum.at(Enum.at(rows,0),0)
    if rows == 0 do
      Logger.info("Stopped pn for #{state.auth.user_id}")
      {:stop, :normal, state}
    else
      auth = %Fluminus.Authorization{
        client: %Fluminus.HTTPClient{
          cookies: %{"idsrv" => state.auth.idsrv}
        },
        jwt: state.auth.jwt
      }
      if state.count == 0 do
        case Fluminus.API.api(auth, "/notification?sortby=recordDate%20desc") do
          {:ok, resp} ->
            Enum.each(resp["data"], fn ann ->
              query_string =
                "INSERT INTO notification VALUES (\"#{state.auth.user_id}\", #{ann["id"]})"
              SQL.query(FluminusServer.Repo, query_string, [])
            end)
            time =
              DateTime.utc_now()
              |> DateTime.to_time()
              |> Time.to_iso8601()
            Logger.info("Initialized db for #{state.auth.user_id} at #{time}")
            Process.send_after(self(), :tick, @fetch_interval)
            {:noreply, %{auth: state.auth, count: state.count+1}}

          {:error, reason} ->
            Logger.error(Kernel.inspect(reason))
            {:noreply, state}
        end
      else
        case Fluminus.API.api(
          if rem(state.count, @renew_count) == 0 do
            case Fluminus.Authorization.renew_jwt(auth) do
              {:ok, renewed_auth} ->
                Logger.info("Renewed JWT for #{state.auth.user_id}")
                renewed_auth
              {:error, reason} ->
                Logger.error("Failed to renew JWT for #{state.auth.user_id}, reason: " <> Kernel.inspect(reason))
                auth
            end
          else
            auth
          end,
          "/notification?sortby=recordDate%20desc&limit=#{@limit}") do
          {:ok, resp} ->
            Enum.each(resp["data"], fn ann ->
              query_string =
                "SELECT COUNT(*) FROM notification WHERE user_id=\"#{state.auth.user_id}\" AND id=#{ann["id"]}"
              {:ok, %Mariaex.Result{
                columns: _,
                connection_id: _,
                last_insert_id: _,
                num_rows: _,
                rows: rows
              }} = SQL.query(FluminusServer.Repo, query_string, [])
              rows = Enum.at(Enum.at(rows,0),0)
              if rows == 0 do
                query_string =
                  "INSERT INTO notification VALUES (\"#{state.auth.user_id}\", #{ann["id"]})"
                SQL.query(FluminusServer.Repo, query_string, [])
                query_string =
                  "SELECT fcm_token FROM pn WHERE user_id=\"#{state.auth.user_id}\""
                {:ok, %Mariaex.Result{columns: _, connection_id: _, last_insert_id: _, num_rows: _, rows: fcm_token_rows}} = SQL.query(FluminusServer.Repo, query_string, [])
                fcm_token = Enum.at(Enum.at(fcm_token_rows,0),0)
                # Logger.info(Kernel.inspect(res))
                payload = Map.put(ann, "fcm_token", fcm_token)
                # Logger.info(Kernel.inspect(payload))
                {:ok, json} = Jason.encode(payload)
                case HTTPoison.post("http://127.0.0.1:3004/send_pn", json, [{"Content-Type", "application/json"}]) do
                  {:ok, _} ->
                    Logger.info("Successfully sent push notification request for #{state.auth.user_id}")
                  {:error, reason} ->
                    Logger.error("Failed to send pn request for #{state.auth.user_id}, reason: " <> Kernel.inspect(reason))
                end
                Logger.info(Kernel.inspect(ann))
              end
            end)
            time =
              DateTime.utc_now()
              |> DateTime.to_time()
              |> Time.to_iso8601()
            Logger.info("Updated for #{state.auth.user_id} at #{time}")
            Process.send_after(self(), :tick, @fetch_interval)
            {:noreply, %{auth: state.auth, count: state.count+1}}

          {:error, reason} ->
            Logger.error(Kernel.inspect(reason))
            {:noreply, state}
        end
      end
    end
  end
end

defmodule FluminusServerWeb.DefaultController do
  use FluminusServerWeb, :controller

  require Logger

  def index(conn, _params) do
    text(conn, "connected!")
  end

  @spec deactivate_pn(Plug.Conn.t(), any) :: Plug.Conn.t()
  def deactivate_pn(conn, params) do
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
                q1 = "DELETE FROM pn WHERE user_id=\"#{map["userID"]}\""
                q2 = "DELETE FROM notification WHERE user_id=\"#{map["userID"]}\""
                case SQL.query(FluminusServer.Repo, q1, []) do
                  {:ok, _} ->
                    SQL.query(FluminusServer.Repo, q2, [])
                    conn |> send_resp(200, "")

                  _ -> conn |> send_resp(400, "This user doesn't exist")
                end

              _ ->
                conn |> send_resp(500, "")
            end

          {:error, :invalid_authorization} ->
            conn |> send_resp(400, "Invalid credentials")

          _ ->
            conn |> send_resp(500, "")
        end

      _ ->
        conn |> send_resp(400, "Please provide both idsrv and jwt as strings")
    end
  end

  @spec activate_pn(Plug.Conn.t(), any) :: Plug.Conn.t()
  def activate_pn(conn, params) do
    case params do
      %{"idsrv" => idsrv, "jwt" => jwt, "fcm_token" => fcm_token} ->
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
                query_string =
                  "INSERT INTO pn VALUES (\"#{map["userID"]}\", \"#{
                    renewed_auth.client.cookies["idsrv"]
                  }\", \"#{renewed_auth.jwt}\", \"#{fcm_token}\", curtime())"
                case SQL.query(FluminusServer.Repo, query_string, []) do
                  {:ok, _} ->
                    GenServer.start(PeriodicTask, %Authorization{
                      idsrv: renewed_auth.client.cookies["idsrv"],
                      jwt: renewed_auth.jwt,
                      user_id: map["userID"]
                    })
                    conn |> send_resp(201, "Enabled push notification for " <> map["userID"])
                  _ -> :error
                end

              _ ->
                conn |> send_resp(500, "")
            end

          {:error, :invalid_authorization} ->
            conn |> send_resp(400, "Invalid credentials")

          _ ->
            conn |> send_resp(500, "")
        end

      _ ->
        conn |> send_resp(400, "Please provide both idsrv and jwt as strings")
    end
  end
end
