// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

// Maverick serves this site under the group path, not domain root:
// https://maverick.eecs.ucf.edu/seniordesign/fa2026sp2027/g19/
const MAVERICK_BASE = '/seniordesign/fa2026sp2027/g19/';

// Local `astro dev` uses "/" so http://localhost:4321 works without the prefix.
// Production `astro build` (and deploy) uses the Maverick path.
// Override anytime: SITE_BASE=/ npm run build
const isDev = process.argv.includes('dev');
const siteBase = process.env.SITE_BASE ?? (isDev ? '/' : MAVERICK_BASE);

// https://astro.build/config
export default defineConfig({
  base: siteBase,
  vite: {
    plugins: [tailwindcss()]
  }
});
