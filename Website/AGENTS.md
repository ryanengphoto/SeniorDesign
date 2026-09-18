# Website — Agent notes

Public Astro site. Distinct from the operator console in `GUI/`.

Prototype status: [`state.md`](state.md).

## Deploy (Maverick)

Pre-authorized — run without asking the user each time:

```bash
cd Website && ./deploy-maverick.sh --build
```

Live: https://maverick.eecs.ucf.edu/seniordesign/fa2026sp2027/g19/

Credentials: gitignored `Website/.env`. Sandbox allowlist includes `maverick.eecs.ucf.edu` (see `.cursor/sandbox.json`). Prefer Shell **without** escalating to `full_network`/`all`. Never brand the site with a project-title acronym.

## Development

When starting the dev server, use background mode:

```
astro dev --background
```

Manage the background server with `astro dev stop`, `astro dev status`, and `astro dev logs`.

## Documentation

Full documentation: https://docs.astro.build

Consult these guides before working on related tasks:

- [Adding pages, dynamic routes, or middleware](https://docs.astro.build/en/guides/routing/)
- [Working with Astro components](https://docs.astro.build/en/basics/astro-components/)
- [Using React, Vue, Svelte, or other framework components](https://docs.astro.build/en/guides/framework-components/)
- [Adding or managing content](https://docs.astro.build/en/guides/content-collections/)
- [Adding styles or using Tailwind](https://docs.astro.build/en/guides/styling/)
- [Supporting multiple languages](https://docs.astro.build/en/guides/internationalization/)
