# FastAPI (observability)

Minimal FastAPI service for local observability testing.

Endpoints:
- `GET /health`
- `GET /sleep?ms=200`
- `GET /chain?ms=200` (optional downstream call via `DOWNSTREAM_URL`)

