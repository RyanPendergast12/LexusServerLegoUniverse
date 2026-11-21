# Instructions for Claude Code

This repo is the owner's personal website, **ryanpendergast.com**, hosted on Hostinger.

- The whole site is the single self-contained file `index.html` (HTML + CSS + vanilla JS).
  Keep it that way: no frameworks, build steps or external scripts, so the owner can
  upload one file in Hostinger File Manager or paste it into a Website Builder
  "Embed code" element.
- The intro is a canvas animation (a 3D tree of text characters, z-buffered into a
  character grid). After **Enter site**, four tabs (About / Projects / Map / Contact) appear.
  Tabs use `role="tab"` / `role="tabpanel"`, arrow-key navigation and `#hash` links.
- The Map tab iframes `/map/`, a static BlueMap snapshot deployed separately to
  `public_html/map/` (not in git; see README). Don't add it to the repo.
- Respect `prefers-reduced-motion`. The page must work at phone width (390 px) without
  horizontal scrolling, and the content must stay readable without JavaScript.
- Don't publish the owner's email or phone number on the page unless they ask.
- Deployment steps for the owner are in `README.md`.
