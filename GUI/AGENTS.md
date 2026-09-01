# GUI — Agent notes

Operator console (`backend/` FastAPI + `frontend/` React). Distinct from the marketing site in `Website/`.

## Development

Run Make targets from `GUI/` (or `make -C GUI <target>` from the repo root). **Do not** substitute absolute home-directory paths.

| Target | Action |
| --- | --- |
| `make dev` | Install deps, start backend, wait for health, then frontend |
| `make backend` | API only — http://localhost:8000 |
| `make frontend` | Dashboard only — requires backend already running |
| `make install` | Dependencies only |
| `make build` | `frontend/dist/` production build |
| `make stop` | Free ports 8000 and 5173 |

Open the **dashboard** at port 5173. Port 8000 is the API (`/api/health`, WebSocket `/ws`).

When starting or debugging the stack, use these Make targets instead of ad-hoc `uvicorn` / `npm run dev` command lines.
