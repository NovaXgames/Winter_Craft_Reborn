# Wintercraft Web API

The launcher now uses one shared HTTP API for two features:

- Wintercraft accounts
- hosted-server ownership and provisioning metadata

The intended public shape is:

- site homepage on `/`
- launcher and site API on `/api`

Example base URL:

```conf
wintercraft_api_url = http://192.168.192.143:3200/api
wintercraft_hosting_public_host = 192.168.192.143
```

`wintercraft_hosting_api_url` is still accepted as a legacy fallback, but `wintercraft_api_url` should be used for new installs.

## Auth endpoints

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `POST /auth/logout`

### Register/Login payload

```json
{
  "username": "nova",
  "password": "secret123"
}
```

### Register/Login response

```json
{
  "token": "session-token",
  "account": {
    "id": 1,
    "username": "nova"
  }
}
```

The launcher stores the bearer token locally and reuses it automatically for hosted-server requests.

## Hosted server endpoints

- `GET /servers`
- `POST /servers`
- `PUT /servers/{id}`
- `DELETE /servers/{id}`

Fallback compatibility endpoints are also supported:

- `POST /servers/{id}/update`
- `POST /servers/{id}/delete`

## Hosted server create payload

```json
{
  "name": "My Winter Server",
  "description": "Snow map",
  "admin_name": "nova",
  "admin_password": "secret",
  "gameid": "wintercraft_game"
}
```

## Hosted server response

```json
{
  "server": {
    "id": "srv_123",
    "name": "My Winter Server",
    "description": "Snow map",
    "admin_name": "nova",
    "host_address": "192.168.192.143",
    "host_port": 30000,
    "status": "queued",
    "gameid": "wintercraft_game"
  }
}
```

The API never returns the raw admin password. The launcher may keep a local copy for convenience on the same device.
