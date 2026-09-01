# Website prototype state

**Last updated:** 2026-09-01  
**Status:** Static marketing site — layout and content structure in place; team content and deployment are not finished.

**Run:** `cd Website && npm install && npm run dev` → http://localhost:4321

---

## Next steps (work in this order)

### Required — minimum shippable

- [ ] Replace placeholder team names, roles, and photos on `/team` (`team.astro`)
- [ ] Remove “Replace the placeholders…” helper text from team page
- [ ] Confirm advisor names/titles with faculty list
- [ ] Run `npm run build` and fix any errors; smoke-test `npm run preview`
- [ ] Deploy to chosen host (GitHub Pages, course server, etc.) and record URL in `README.md`
- [ ] Review home copy against **actual** demo scope; soften claims if hardware is not ready

### Recommended — polish

- [ ] Add project GitHub (or repo) link in footer or nav
- [ ] Add 1–2 hardware/GUI screenshots or demo video on home or architecture section
- [ ] Mobile-friendly nav (hamburger / collapsible)
- [ ] Open Graph meta for link previews
- [ ] Custom 404 page
- [ ] Optional: link to senior design report PDF in `Docs/` if publishable

### Optional

- [ ] `Makefile` with `make dev` / `make build` (parity with `GUI/`)
- [ ] Content collection for team members (move data out of inline arrays)
- [ ] `astro check` in CI or pre-commit
- [ ] Link to operator console (`GUI/`) — only if it should be public

### Verification still open

- [ ] Deployed URL loads for committee
- [ ] Team page shows real people

---

## At a glance

| Area | Status |
| --- | --- |
| Home page (`/`) | **Built** — hero, overview, security, architecture |
| Team page (`/team`) | **Built** — layout only; **placeholder names/photos** |
| Shared layout, nav, theme | **Built** |
| Scroll animations | **Built** |
| Block diagram on home | **Built** — imports `Docs/BlockDiagrams/Rendered/bd1.jpg` |
| `README.md` | **Updated** — project run/build notes |
| Production deploy | **Not done** |
| Real team bios / photos | **Not done** |
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
| `README.md` | Project-specific run and build instructions |

### Pages

| Route | File | Sections |
| --- | --- | --- |
| `/` | `src/pages/index.astro` | Hero, overview specs list, security feature cards, block diagram, footer |
| `/team` | `src/pages/team.astro` | Member grid, faculty advisors, back link |

### Components and layout

| Component | File | Role |
| --- | --- | --- |
| `Base` | `src/layouts/Base.astro` | HTML shell, meta, fonts, favicon, view transitions, animation script |
| `Nav` | `src/components/Nav.astro` | Fixed top nav — Overview, Security, Architecture, Team |
| `Hero` | `src/components/Hero.astro` | Title, tagline, CTA buttons |

### Styling, motion, assets

| Item | Location |
| --- | --- |
| Design tokens (dark theme) | `src/styles/global.css` |
| Scroll / hero animations | `src/scripts/animations.ts` |
| Favicon | `public/favicon.svg`, `public/favicon.ico` |
| Block diagram | `Docs/BlockDiagrams/Rendered/bd1.jpg` via Astro import |

Copy is **inline arrays** in page frontmatter — not a CMS or content collection.

---

## Placeholder and aspirational content

### Explicit placeholders (must replace before “done”)

| Item | Location | Current value |
| --- | --- | --- |
| Team member names | `team.astro` | `Team Member 1` … `Team Member 4` |
| Team roles | `team.astro` | Generic role strings |
| Member photos | `team.astro` | `?` circle avatars — no images |
| On-page hint | `team.astro` | “Replace the placeholders below…” |

### Aspirational copy (target system, not built hardware)

Home page security features and specs follow `Docs/init_specs.md`. They describe **design intent**, not verified prototype behavior. Review before deploy (see Next steps).

### Hardcoded values (centralize when content grows)

| Value | Where |
| --- | --- |
| `Senior Design 2026` | `Hero.astro` |
| Advisor list | `team.astro` |
| Feature/spec arrays | `index.astro` |

---

## Not built yet

| Item | Notes |
| --- | --- |
| Deployment | No hosting config checked in |
| Mobile navigation | No hamburger for small screens |
| SEO / social | No Open Graph beyond basic `description` |
| 404 page | Default Astro only |
| Demo media | No hardware/GUI photos or video |
| Downloads | No report/poster/schematic links |
| Contact / GitHub in footer | Minimal footer today |
| Content collections | All inline in `.astro` files |
| Accessibility pass | No audit |

---

## Verification (manual)

- [x] `npm run dev` serves home and team pages
- [x] Nav anchor links work on home (`#overview`, `#security`, `#architecture`)
- [x] Block diagram renders from `Docs/BlockDiagrams/Rendered/bd1.jpg`
- [x] Animations run without console errors
- [x] `README.md` describes this project
- [ ] `npm run build` recorded as verified release step
- [ ] Deployed URL loads for committee
- [ ] Team page shows real people

---

## Related docs

| Doc | Contents |
| --- | --- |
| `Website/README.md` | Run and build commands |
| `Website/AGENTS.md` | Astro dev server conventions |
| `Docs/init_specs.md` | Requirements source for marketing copy |
| `GUI/state.md` | Operator console prototype status |
| `AGENTS.md` | Repo-wide agent rules |

---

## Maintenance

Update **Next steps** checkboxes first when work completes. Also update when the site is deployed (add URL near the top) or when marketing copy changes.
