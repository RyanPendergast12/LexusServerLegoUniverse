# RyanPendergast.com

Personal cybersecurity website. Everything is in one file: `index.html`. It needs no
libraries, build step or server code.

1. **Intro.** A 3D Christmas tree made of about 30,000 text characters builds itself
   and spins: trunk, branches, gold garland, baubles, twinkling lights, star and presents,
   with falling snow. Then **RyanPendergast.com** types out and an **Enter site** button
   appears. **Skip intro** (top right) jumps straight in.
2. **Site.** Five tabs: **About**, **Projects**, **ATHLETE**, **Map** and **Contact**. The tree keeps
   spinning, dimmed, in the background.

The **Map** tab embeds `/map/`, a static BlueMap snapshot of the BTE Las Vegas Minecraft
world. It is NOT in this repo (≈390 MB): it lives only in `public_html/map/` on Hostinger.
Rebuild it with `C:\BTE-Migration\bluemap\website-snapshot\build_snapshot.ps1`, then upload
`bluemap-site.zip` into `public_html/map/` and extract it there (it includes the
`.htaccess` the map needs to serve its gzip tiles).

Links straight to a tab skip the intro: `ryanpendergast.com/#projects`.

## ATHLETE page

`athlete/index.html` is a static landing page for the ATHLETE app, served at `/athlete/`. Its screenshots in
`athlete/img/` come from ATHLETE's automated review with a fictional athlete. The app itself runs separately
(Render); the portfolio only links to it. Registration links are added once the app's beta is verified.

## Preview

Double-click `index.html` to open it in any browser.

## Put it on Hostinger

### Option A: Hostinger web hosting (best: full-screen intro)

1. In **hPanel**, open **Websites → ryanpendergast.com → File Manager**.
2. Open `public_html`, delete or rename the existing `index.html` / `default.php`, and
   upload this `index.html`.
3. Visit https://ryanpendergast.com (hard refresh: Ctrl+F5).

> If the domain is currently connected to **Hostinger Website Builder**, first switch it
> to web hosting: hPanel → Websites → *Add website* → *Empty PHP/HTML website*, pick
> ryanpendergast.com, then upload as above. Your plan must include web hosting
> (Premium/Business do; a Website-Builder-only plan does not).

### Option B: keep Hostinger Website Builder

1. Open the builder, **Add element → Embed code**.
2. Paste the whole contents of `index.html`.
3. Stretch the embed box to full width and about 800 px tall, then **Publish**.

The animation runs inside that box rather than taking over the whole page, and the
builder's own header and footer stay around it.

## Editing the text

Open `index.html` in any text editor and search for:

- `TAB 1: About`, `TAB 2: Projects`, `TAB 3: Map` or `TAB 4: Contact`: the content of each tab.
- `YOUR-EMAIL-HERE` / `YOUR-PROFILE`: email and LinkedIn cards, commented out until
  you fill them in (delete the `<!--` and `-->` around them).
- `const NAME = 'RyanPendergast.com'`: the name typed in the intro.
- `--accent: #3ddc84`: the main green colour.

## History

This repo used to hold a Docker setup for a private LEGO Universe server. That code
is still on the `master` branch and in git history.
