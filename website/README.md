# XPENC website

The landing page served at https://getxpenc.vercel.app — a single static page
(`index.html`, no build step) plus the privacy policy (`privacy.html`, served
at `/privacy` via `cleanUrls`). Dependency-free by design: no JS libraries, no
CDN scripts — the only external requests are Google Fonts and one GitHub API
call for the live version pill (static fallback baked in).

Design: One UI–inspired dark minimal — true-black background, large rounded
cards, Space Grotesk + Inter, matching the app's monochrome AMOLED theme.

## Deploying (Vercel)

The Vercel project (`xpenc`) is **CLI-linked, not Git-connected** — pushing to
GitHub does *not* redeploy. Deploy manually:

```sh
cd website
vercel --prod
```

To get push-to-deploy instead: Vercel dashboard → xpenc → Settings → Git →
connect `PATILYASHH/XPENC` with Root Directory `website`.

`vercel.json` adds security headers, long-cache for `assets/`, and `cleanUrls`
(so `/privacy` serves `privacy.html`).

## Local preview

Just open `index.html` in a browser, or:

```sh
npx serve website
```

## Notes

- Download buttons point at
  `github.com/PATILYASHH/XPENC/releases/latest/download/xpenc-<abi>.apk` —
  stable asset names published by `.github/workflows/release.yml`. Keep them in sync.
- README deep-links to `/#download` and `/#features` — keep those anchor ids.
- The version pill is fetched live from the GitHub Releases API with a static fallback.
- Icons in `assets/` are copies of `branding/` output — regenerate with
  `python tool/generate_icons.py` and re-copy if the brand mark changes.
- `privacy.html` mirrors `PRIVACY.md` at the repo root — update both together,
  and bump the effective date.
