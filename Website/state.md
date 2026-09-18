# Website prototype state

**Last updated:** 2026-09-17  
**Status:** Public site for assignment — PDF linked, team/faculty from D&C cover, architecture diagrams hidden.  
**Live:** https://maverick.eecs.ucf.edu/seniordesign/fa2026sp2027/g19/

---

## Next steps (work in this order)

### Required — minimum shippable

- [x] Replace placeholder team names on `/team` (`team.astro`)
- [x] Remove “Replace the placeholders…” helper text from team page
- [ ] Confirm advisor names/titles with faculty list
- [x] Run `npm run build` and fix any errors; smoke-test `npm run preview`
- [ ] Add `public/docs/divide-and-conquer.pdf` (Divide and Conquer / project proposal)
- [x] Deploy to Maverick (`./deploy-maverick.sh`) and record URL in `README.md` / `state.md`
- [ ] Review home copy against **actual** demo scope; soften claims if hardware is not ready

### Recommended — polish

- [ ] Add project GitHub (or repo) link in footer or nav
- [ ] Add team photos (optional) and/or hardware/GUI screenshots
- [ ] Mobile-friendly nav (hamburger / collapsible)
- [ ] Open Graph meta for link previews
- [ ] Custom 404 page

### Optional

- [ ] `Makefile` with `make dev` / `make build` (parity with `GUI/`)
- [ ] Content collection for team members (move data out of inline arrays)
- [ ] `astro check` in CI or pre-commit
- [ ] Link to operator console (`GUI/`) — only if it should be public

### Verification still open

- [ ] Deployed URL loads for committee
- [ ] Divide and Conquer PDF downloads from Documents section

---

## At a glance

| Area | Status |
| --- | --- |
| Home page (`/`) | **Built** — hero, overview, security, architecture diagrams, documents |
| Team page (`/team`) | **Built** — Ryan Eng, Victor Valentin, Lukas Zavaleta, Kyle Kosuda |
| Shared layout, nav, theme | **Built** |
| Scroll animations | **Built** |
| Block diagrams on home | **Built** — `pcb_bd_1.jpg`, `fabric_bd.jpg`, `software.jpg` |
| Documents section | **Built** — link for Divide and Conquer PDF; file not added yet |
| `README.md` | **Updated** |
| Production deploy | **Done** — Maverick `public_html` (2026-09-17) |
| Team photos | **Not done** (initials avatars) |
| Makefile | **Not done** (npm scripts only) |
| Automated tests / `astro check` | **Not done** |

---

## What this is (vs `GUI/`)

| | `Website/` | `GUI/` |
| --- | --- | --- |
| Purpose | Public project page for committee / portfolio | Operator console for the device |
| Audience | Visitors, reviewers | Team / live demo |
| Data | Static copy | Live WebSocket telemetry |
| Stack | Astro 7 + Tailwind v4 + Motion | Vite + React + FastAPI |

Do not merge these into one app. The website explains the project; the GUI operates it.

---

## Built and real

### Tooling

| Item | Notes |
| --- | --- |
| `package.json` | Astro 7, Tailwind 4, Motion; Node ≥ 22.12 |
| `astro.config.mjs` | Tailwind via Vite plugin |
| `.gitignore` | Standard Node/Astro ignores |
| `Website/AGENTS.md` | Astro dev conventions |
| `README.md` | Project run/build/deploy notes |
| `deploy-maverick.sh` | rsync `dist/` to Maverick `public_html` |

### Pages

| Route | File | Sections |
| --- | --- | --- |
| `/` | `src/pages/index.astro` | Hero, overview, security, architecture diagrams, documents |
| `/team` | `src/pages/team.astro` | Member grid (real names), faculty advisors |

### Components and layout

| Component | File | Role |
| --- | --- | --- |
| `Base` | `src/layouts/Base.astro` | HTML shell, meta, fonts, favicon, view transitions, animation script |
| `Nav` | `src/components/Nav.astro` | Fixed top nav — Overview, Security, Architecture, Documents, Team |
| `Hero` | `src/components/Hero.astro` | Title, tagline, CTA buttons |

### Styling, motion, assets

| Item | Location |
| --- | --- |
| Design tokens (dark theme) | `src/styles/global.css` |
| Scroll / hero animations | `src/scripts/animations.ts` |
| Favicon | `public/favicon.svg`, `public/favicon.ico` |
| Block diagrams | `Docs/BlockDiagrams/Rendered/{pcb_bd_1,fabric_bd,software}.jpg` via Astro import |
| Proposal PDF slot | `public/docs/divide-and-conquer.pdf` (add file; see `public/docs/README.md`) |

Copy is **inline arrays** in page frontmatter — not a CMS or content collection.

---

## Placeholder and aspirational content

### Explicit placeholders remaining

| Item | Location | Notes |
| --- | --- | --- |
| Advisor short names | `team.astro` | Confirm full titles with faculty |
| Proposal PDF | `public/docs/` | Drop-in path ready; file not present |
| Team photos | `team.astro` | Initials only |

### Aspirational copy (target system, not built hardware)

Home page security features and specs follow `Docs/init_specs.md` / `Docs/d_c_txt.md`. They describe **design intent**, not verified prototype behavior. Review before deploy (see Next steps).

### Hardcoded values (centralize when content grows)

| Value | Where |
| --- | --- |
| Project name | Hero, Base, titles, footer |
| Team member list | `team.astro` |
| Advisor list | `team.astro` |
| Feature/spec arrays | `index.astro` |

---

## Not built yet

| Item | Notes |
| --- | --- |
| Deployment | Script exists; not yet run to Maverick |
| Mobile navigation | No hamburger for small screens |
| SEO / social | No Open Graph beyond basic `description` |
| 404 page | Default Astro only |
| Demo media | `prototype.jpg` / `logo.png` available under Rendered but not wired |
| Contact / GitHub in footer | Minimal footer today |
| Content collections | All inline in `.astro` files |
| Accessibility pass | No audit |

---

## Verification (manual)

- [x] `npm run dev` serves home and team pages
- [x] Nav anchor links work on home
- [x] Block diagrams render from updated Rendered assets
- [x] Animations run without console errors
- [x] `README.md` describes this project
- [x] `npm run build` succeeds (2026-09-17)
- [ ] Deployed URL loads for committee
- [ ] Divide and Conquer PDF present and downloadable

---

## Related docs

| Doc | Contents |
| --- | --- |
| `Website/README.md` | Run and build commands |
| `Website/AGENTS.md` | Astro dev server conventions |
| `Docs/init_specs.md` | Requirements source for marketing copy |
| `Docs/d_c_txt.md` | Proposal narrative / engineering tables |
| `GUI/state.md` | Operator console prototype status |
| `AGENTS.md` | Repo-wide agent rules |

---

## Maintenance

Update **Next steps** checkboxes first when work completes. Also update when the site is deployed (add URL near the top) or when marketing copy changes.
