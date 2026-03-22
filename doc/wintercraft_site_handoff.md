# Wintercraft Site Handoff

This handoff is for the agent that will build the public website on the same host/link used by the launcher API.

## Current architecture

- Next.js site app on the server: `/home/vlad/apps/novax-site`
- Wintercraft Hub API service: `/home/vlad/apps/wintercraft-hub-api`
- Dedicated internal API port: `127.0.0.1:3211`
- Nginx site entrypoint used for local/LAN testing: `/etc/nginx/conf.d/novax-site-3200.conf`
- Public launcher API base for LAN testing: `http://192.168.192.143:3200/api`

## Target URL model

- `/` = website homepage and public pages
- `/api/*` = launcher + web API

## API already prepared

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/logout`
- `GET /api/servers`
- `POST /api/servers`
- `PUT /api/servers/{id}`
- `DELETE /api/servers/{id}`

## Data model already present in the API

### Accounts
- username
- password hash
- session tokens

### Hosted servers
- owner account
- server name
- description
- admin name
- admin password hash
- public host address
- public host port
- status

## What still needs website work

1. Public homepage for Wintercraft hosting.
2. Account pages using the same API.
3. Hosted-server dashboard UI wired to `/api/servers`.
4. Proper external domain/Tunnel polish if Cloudflared origin routing changes.
5. Real provisioning workers that consume hosted-server records and create the actual game instances.

## Constraint to preserve

Do not move the API off `/api` and do not change the dedicated backend port away from `3211` without updating both:

- launcher settings / client code
- Nginx reverse proxy
