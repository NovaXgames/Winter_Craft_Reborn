# Wintercraft Hub API

Separate backend for launcher accounts and hosted-server ownership.

## Endpoints

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `POST /auth/logout`
- `GET /servers`
- `POST /servers`
- `PUT /servers/{id}`
- `DELETE /servers/{id}`

This API is meant to live behind Nginx at `/api`, while the site homepage stays on `/`.

## Local run

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --host 127.0.0.1 --port 3211
```

## Notes

- Port `3211` is the dedicated local API port selected for the Wintercraft stack.
- Account sessions are bearer tokens stored server-side in SQLite.
- Hosted servers are account-owned rows for now; actual provisioning can be added later by a worker that consumes the same records.
- Admin passwords are hashed on the API side and are never returned to the launcher.
