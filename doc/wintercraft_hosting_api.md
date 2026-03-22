# Wintercraft Hosting API

This launcher can provision and manage hosted Wintercraft servers through an external HTTP API.

## Launcher settings

Set these values in `minetest.conf` / `luanti.conf` or through the engine settings UI:

- `wintercraft_hosting_api_url`
- `wintercraft_hosting_api_token`
- `wintercraft_hosting_public_host`

`wintercraft_hosting_api_url` must be the API base URL, without the `/servers` suffix.

Example:

```conf
wintercraft_hosting_api_url = https://api.example.net/wintercraft
wintercraft_hosting_api_token = your-secret-token
wintercraft_hosting_public_host = play.example.net
```

## Expected endpoints

The launcher uses these endpoints:

- `GET /servers`
- `POST /servers`
- `PUT /servers/{id}`
- `DELETE /servers/{id}`

Fallback compatibility endpoints are also supported:

- `POST /servers/{id}/update`
- `POST /servers/{id}/delete`

## Request payloads

### Create server

`POST /servers`

```json
{
  "name": "My Winter Server",
  "description": "",
  "admin_name": "nova",
  "admin_password": "secret",
  "gameid": "wintercraft_game"
}
```

### Update server

`PUT /servers/{id}`

```json
{
  "name": "My Winter Server",
  "description": "Snow map",
  "admin_name": "nova",
  "admin_password": "secret"
}
```

## Response shape

The launcher accepts either:

- an array of server objects
- an object with `servers`
- an object with `list`
- an object with `data`
- a single server object

Each server object may contain:

```json
{
  "id": "srv_123",
  "name": "My Winter Server",
  "description": "Snow map",
  "admin_name": "nova",
  "host_address": "play.example.net",
  "host_port": 30000
}
```

Alternative field names also supported by the launcher:

- `server_id`
- `server_name`
- `title`
- `public_host`
- `public_address`
- `server_address`
- `port`

The launcher keeps the admin password only in local profile storage and does not require the API to return it.
