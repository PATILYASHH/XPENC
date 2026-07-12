# XPENC website

The landing page served at https://getxpenc.vercel.app — a single static page
(`index.html`, no build step). The 3D hero (rotating XPENC icon, orbiting
coins, particle field) uses **Three.js** loaded from the jsdelivr CDN as
progressive enhancement — if WebGL or the CDN is unavailable, the page renders
completely without it.

## Deploying (Vercel)

1. [vercel.com/new](https://vercel.com/new) → import `PATILYASHH/XPENC`
2. **Root Directory:** `website` · **Framework Preset:** Other · leave build
   command and output directory empty
3. Deploy. Every push to `master` touching `website/` redeploys automatically.

`vercel.json` adds security headers and long-cache for `assets/`.

## Local preview

Just open `index.html` in a browser, or:

```sh
npx serve website
```

## Notes

- Download buttons point at
  `github.com/PATILYASHH/XPENC/releases/latest/download/xpenc-<abi>.apk` —
  stable asset names published by `.github/workflows/release.yml`. Keep them in sync.
- The version badge is fetched live from the GitHub Releases API with a static fallback.
- Icons in `assets/` are copies of `branding/` output — regenerate with
  `python tool/generate_icons.py` and re-copy if the brand mark changes.
