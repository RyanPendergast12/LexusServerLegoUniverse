# Instructions for Claude Code

This repo is the owner's personal website, **ryanpendergast.com**, hosted on Hostinger.

- The main site is the single self-contained file `index.html` (HTML + CSS + vanilla JS).
  The one exception is `athlete/` (proposed 2026-11-25; applied only after owner approval): a static ATHLETE landing page
  `athlete/index.html` plus its screenshots in `athlete/img/`, also without frameworks or build steps.
  Keep `index.html` itself self-contained: no frameworks, build steps or external scripts, so the owner can
  upload one file in Hostinger File Manager or paste it into a Website Builder
  "Embed code" element.
- The intro is a canvas animation (a 3D tree of text characters, z-buffered into a
  character grid). After **Enter site**, five tabs (About / Projects / ATHLETE / Map / Contact) appear.
  Tabs use `role="tab"` / `role="tabpanel"`, arrow-key navigation and `#hash` links.
- The Map tab iframes `/map/`, a static BlueMap snapshot deployed separately to
  `public_html/map/` (not in git; see README). Don't add it to the repo.
- Respect `prefers-reduced-motion`. The page must work at phone width (390 px) without
  horizontal scrolling, and the content must stay readable without JavaScript.
- Don't publish the owner's email or phone number on the page unless they ask.
- Deployment steps for the owner are in `README.md`.
