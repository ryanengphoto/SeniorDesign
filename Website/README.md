# Senior Design — Project Website

Static public site for the hardware-secure USB hub senior design project. Built with [Astro](https://docs.astro.build).

**Not** the operator console — that lives in [`../GUI/`](../GUI/).

Prototype status: [`state.md`](state.md).

## Run locally

```bash
cd Website
npm install
npm run dev
```

Open http://localhost:4321

## Build for production

```bash
npm run build
npm run preview   # smoke-test dist/
```

Output: `Website/dist/`

## Pages

| Route | Description |
| --- | --- |
| `/` | Project overview, security features, block diagram |
| `/team` | Team and faculty advisors |
