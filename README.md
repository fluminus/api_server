# Fluminus Server

## Get Started

## Database config

```sql
drop table if exists fluminus.pn;
drop table if exists fluminus.notification;
create table if not exists fluminus.pn(
	user_id varchar(255) primary key,
  idsrv varchar(1023),
  jwt varchar(1023),
  fcm_token varchar(255),
  entry_time timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
set time_zone='+08:00';
create table if not exists fluminus.notification(
	user_id varchar(255),
  id integer
);
```

## Request format

### `/api/activate_pn` HTTP POST

```json
{
  "idsrv": "idsrv",
  "jwt": "jwt",
  "fcm_token": "fcm_token"
}
```

### `/api/deactivate_pn` HTTP DELETE

```json
{
  "idsrv": "idsrv",
  "jwt": "jwt"
}
```

## Production mode

* Configure `prod.secret.exs` file

```elixir
config :fluminus_server, FluminusServerWeb.Endpoint,
http: [:inet6, port: String.to_integer(System.get_env("API_SERVER_PORT") || "23333")],
secret_key_base: secret_key_base
```

* Configure `prod.exs` file

```elixir
config :fluminus_server, FluminusServerWeb.Endpoint,
url: [host: "your_running_url", port: 23333],
cache_static_manifest: "priv/static/cache_manifest.json"
```

* Some commands

```bash
export API_SERVER_PORT=23333
mix phx.gen.secret
export SECRET_KEY_BASE=[the secret generated just now]
export DATABASE_URL=ecto://[username]:[password]@localhost/[database_name]
mix phx.digest
mix deps.get --only prod
MIX_ENV=prod mix phx.server
```

## Extras

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).