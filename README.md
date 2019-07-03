# Fluminus Server

## Get Started

## Database config

```sql
create table if not exists fluminus_server_dev.pn(
	username varchar(255),
  idsrv varchar(1023),
  jwt varchar(1023),
  fcm_token varchar(255),
  entry_time timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
set time_zone='+08:00';
create table if not exists fluminus_server_dev.notification(
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

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).