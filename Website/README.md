# USB Peripheral Interface Security System — Website

Static public site for the Senior Design project. Built with [Astro](https://docs.astro.build).

**Not** the operator console — that lives in [`../GUI/`](../GUI/).

Prototype status: [`state.md`](state.md).

**Live site:** https://maverick.eecs.ucf.edu/seniordesign/fa2026sp2027/g19/

---

## Update the live site (usual workflow)

From `Website/`:

```bash
cd Website
./deploy-maverick.sh --build
```

That builds `dist/` (with the correct subdirectory `base` path), then uploads **into the account home** (the Maverick web root for g19).

| Step | What happens |
| --- | --- |
| 1 | Reads credentials from `Website/.env` (gitignored) |
| 2 | Runs `npm run build` when you pass `--build` |
| 3 | Syncs site files → `fa26sp27g19@maverick.eecs.ucf.edu:.` |
| 4 | Removes any leftover nested `public_html/` from older deploys |
| 5 | Site is live at the URL above |

Do **not** deploy into `public_html/` — on this server the group home already *is* the document root (`/seniordesign/fa2026sp2027/g19/`).

### First-time setup (once per machine)

```bash
cd Website
cp .env.example .env
# edit .env and set MAVERICK_PASS (keep MAVERICK_DIR=.)
npm install
./deploy-maverick.sh --build
```

`.env` is gitignored. Do not commit passwords.

### After content-only edits

```bash
cd Website
./deploy-maverick.sh --build
```

(`--build` is recommended so asset URLs stay correct with Astro `base`.)

### Adding / updating the proposal PDF

Source of truth: `Docs/Official_SD_docs/D_and_C_SD1_v2.pdf`

Replace that file, then redeploy — the script syncs it into `public/docs/divide-and-conquer.pdf` and rebuilds if the PDF changed:

```bash
./deploy-maverick.sh
# or force a full rebuild:
./deploy-maverick.sh --build
```

Linked from `/documents/`. See [`public/docs/README.md`](public/docs/README.md).

### Deploy notes

- Astro `base` is `/seniordesign/fa2026sp2027/g19/` in `astro.config.mjs` so CSS/JS/images resolve under the group path
- Upload uses the Python SFTP helper (`.venv-deploy`) and only replaces managed site files (`index.html`, `_astro/`, `team/`, …) — it does not wipe the whole home directory
- Optional `.env` keys: `MAVERICK_HOST`, `MAVERICK_USER`, `MAVERICK_DIR` (keep `.`), `MAVERICK_PASS`
- Agents are pre-authorized to redeploy (see `.cursor/rules/website-deploy.mdc` and `.cursor/permissions.json`)

**One-time Cursor setup** (so agents stop asking to Allow each deploy):

1. Open **Cursor Settings → Agents → Approvals & Execution**
2. Set Run Mode to **Allowlist (with Sandbox)** or **Auto-review**
3. Add these terminal allowlist entries (click **Add to allowlist** when a deploy prompt appears, or add manually):

```text
./deploy-maverick.sh
Website/deploy-maverick.sh
```

4. Reload the window if prompts still appear after editing `.cursor/sandbox.json` / `.cursor/permissions.json`

Project files already configured for this:
- `.cursor/sandbox.json` — allows network to Maverick
- `.cursor/permissions.json` — Auto-review guidance to approve deploys
- `.cursor/rules/website-deploy.mdc` — agents treat redeploy as pre-authorized

---

## Local development

```bash
cd Website
npm install
npm run dev
```

Open http://localhost:4321 — **local `dev` uses `base: '/'`**, so paths work at the root.

Production builds (`npm run build` / `./deploy-maverick.sh --build`) use the Maverick subdirectory base automatically. After a production build, `npm run preview` expects the prefixed URL:

http://localhost:4321/seniordesign/fa2026sp2027/g19/

To force a root production build locally: `SITE_BASE=/ npm run build`
## Pages

| Route | Description |
| --- | --- |
| `/` (under site base) | Project overview, security features, block diagrams, documents |
| `/team/` | Team and faculty advisors |
