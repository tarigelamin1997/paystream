# PayStream Feature Store API

FastAPI service serving user credit features from ClickHouse.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/features/user/{user_id}` | Fetch credit features (optional `?as_of=` for point-in-time) |
| GET | `/health` | ALB health check |
| GET | `/metrics` | Prometheus metrics |

## Configuration

All configuration via environment variables:

- `CLICKHOUSE_HOST` — ClickHouse server (default: `localhost`)
- `CLICKHOUSE_PORT` — Native TCP port (default: `9000`)
- `FEATURE_VERSION` — Feature version to query (default: `v2.1.0`)

## Run locally

```bash
pip install -r requirements.txt
uvicorn feature_store.main:app --host 0.0.0.0 --port 8000 --workers 2
```

## Docker

```bash
docker build -t paystream-fastapi .
docker run -p 8000:8000 -e CLICKHOUSE_HOST=host.docker.internal paystream-fastapi
```

## Tests

```bash
pip install pytest httpx
pytest tests/
```
