# Website documents

Synced automatically by `./deploy-maverick.sh` (via `scripts/sync_docs.sh`).

| Public file | Site link | Source of truth |
| --- | --- | --- |
| `divide-and-conquer.pdf` | `/docs/divide-and-conquer.pdf` | `Docs/Official_SD_docs/D_and_C_SD1_v2.pdf` |

Do **not** edit copies under `public/docs/` by hand for official PDFs — update the file in `Docs/Official_SD_docs/`, then redeploy. The deploy script copies newer/changed sources into `public/docs/` and rebuilds when documents change.
