# igou.io rebuild — design

**Date:** 2026-05-31
**Status:** Approved (pending spec review)

## Goal

Replace the old Jekyll blog (and the abandoned mkdocs migration) with a modern,
**static, ultra-lightweight, dark-only** site. Priorities, in order:

1. Extremely fast and lightweight to load — minimal bytes, minimal requests.
2. As little JavaScript / client-side rendering as possible (target: **zero JS**).
3. Easy to add blog posts (drop a markdown file).
4. Dark mode (dark-only, no toggle).

## Decisions (from brainstorming)

| Decision | Choice |
| --- | --- |
| Generator | **Hugo** with a hand-written minimal theme (templates in `layouts/`, no `themes/` dir, no pre-built theme) |
| Dark mode | **Dark-only**, pure CSS, zero JS |
| Old posts | **Start fresh.** Old Jekyll content not migrated; `old/` has since been removed entirely (its rotation images were copied into `assets/home/` first) |
| Homepage | **Centered splash** like the original (image in the middle, name, inline `blog / about / github / contact` links), styled after cca.org's minimalism but dark. Post list lives at `/blog`, not the home page |
| Splash image | **Build-time random** — Hugo picks one of `assets/home/*.jpg` per build and resizes/optimizes only that one. Zero JS; recreates the original's rotating image without client-side `Math.random` |
| Deployment | **Stock `nginx:alpine` Podman Quadlet** that mounts a host directory of built files read-only. **No custom image, no registry.** |
| Build location | **Host builds from this repo** — `hugo` (or a one-shot podman hugo container) writes `public/` straight into the served directory |
| Branding | **Minimal** — name "David Igou" + a GitHub link, no tagline |

## Philosophy / output budget

- **Zero JavaScript** ships to the browser.
- **No web fonts.** System font stack for body text, system monospace stack for code — no font downloads.
- **One small CSS file** (target ~2 KB), dark theme.
- **Build-time syntax highlighting** via Hugo's built-in Chroma (a dark style). Colored code with no client-side highlighter and no extra requests.
- A typical post = 1 HTML request + 1 CSS file. No JS, no external/CDN assets, no trackers.

## Repository layout

Hugo lives at the repo root. Custom templates live directly in `layouts/` — there is
no `themes/` directory and no third-party theme.

```
hugo.toml                    # site config (baseURL, title, params, markup/highlight)
archetypes/default.md        # template used by `hugo new blog/<name>.md`
content/
  about.md                   # short about / self page
  contact.md                 # contact page (email + links)
  blog/
    _index.md                # optional intro copy at top of the /blog list
    hello-world.md           # one starter post (demonstrates code block + frontmatter)
layouts/
  index.html                 # homepage: centered splash (image, name, inline links) — standalone, no site chrome
  _default/baseof.html       # HTML shell for content pages: small header (name → home), content, footer
  _default/single.html       # a single blog post
  _default/list.html         # the /blog listing (reverse-chron posts)
assets/
  home/                      # pool of splash images; Hugo random-picks + resizes one per build
static/
  css/style.css              # the one stylesheet (dark-only)
deploy/
  igou-io.container          # Podman Quadlet unit (stock nginx:alpine + volume mount)
  build.sh                   # build the site into the served dir (host hugo or podman one-shot)
  README.md                  # one-time setup notes (quadlet install, paths)
.github/workflows/master.yml # build-verification only (no deploy)
```

## Authoring flow

- `hugo new blog/my-title.md` scaffolds frontmatter from `archetypes/default.md`,
  or simply create the markdown file by hand under `content/blog/`.
- Frontmatter: `title` (string), `date` (ISO date), optional `tags` (list).
- `draft: true` keeps a post out of the build until ready.
- Write markdown, commit → next host build publishes it.

## Homepage (the splash)

Faithful to the original igou.io home and inspired by the ultra-minimal, whitespace-
driven, content-first feel of cca.org — rendered dark:

- A single centered column, vertically and horizontally centered in the viewport.
- One image in the middle, **picked at random at build time** from `assets/home/*.jpg`
  (seeded by build time). Hugo resizes/optimizes only the chosen image. Zero JavaScript
  — recreates the original site's rotating image without a client-side script.
- The name **"David M Igou"** beneath the image.
- A single row of inline text links, cca-style separated by ` / `:
  **blog / about / github / contact**. `blog`, `about`, `contact` are internal pages;
  `github` is an external link to github.com/david-igou.
- No site header/footer chrome on the splash itself — it stands alone.

## Pages & URLs

- `/` — the splash (above). No post list here.
- `/blog/` — reverse-chronological list of posts (title + date).
- `/blog/<slug>/` — individual posts.
- `/about/` — short about / self page.
- `/contact/` — contact page (email + links).
- `/index.xml` — RSS feed (Hugo built-in, generated at build, zero JS).
- `/sitemap.xml` — sitemap (Hugo built-in).

Content pages (`/blog`, posts, `/about`, `/contact`) carry a small header — the name
linking back to `/` — and a minimal footer. The splash is the only chrome-less page.

Out of scope for v1 (YAGNI; trivial to add later): tag/category pages, pagination,
client-side search, comments, analytics.

## Styling (dark-only)

- A single dark palette defined with CSS custom properties at the top of `style.css`.
- System font stacks; readable measure (max content width ~ 40–46rem, centered).
- cca.org-inspired minimalism: inline ` / `-separated links, whitespace for hierarchy,
  no boxes/borders/decoration beyond what's needed.
- The splash uses fl/centering CSS (e.g. a flex column) to sit mid-viewport; the image
  has a sensible max-width so it never dominates on large screens.
- Minimal, semantic HTML. Visible focus styles and adequate contrast for accessibility.
- Chroma dark highlight style configured in `hugo.toml` (`markup.highlight`), emitted
  as inline classes/styles at build time.

## Images

- The splash pool lives in `assets/home/` (the original rotation set `1–13.jpg` plus
  `des-allant.jpg`; the stray `0.jpg`, actually a GIF, is excluded). At each build Hugo
  random-picks one and `.Resize "600x q80"` produces an optimized JPEG (~65 KB) — so
  only the chosen image is published and the homepage stays light (total ~68 KB).
- Originals are committed to `assets/`; resized derivatives go to `public/` only.

## Build & deploy

**No custom container image and no registry.** A stock `nginx:alpine` serves files
from a host directory that the host populates by building this repo with Hugo.

### Host build — `deploy/build.sh`

Builds the site into the served directory (default `/srv/www/igou.io`, overridable via
an env var / arg). Two interchangeable mechanisms, both producing the same `public/`:

- **Host hugo** (if Hugo is installed, e.g. via mise):
  ```sh
  hugo --minify --source "$REPO" --destination "$OUT_DIR"
  ```
- **Podman one-shot** (no host Hugo dependency):
  ```sh
  podman run --rm \
    -v "$REPO":/src:ro,Z \
    -v "$OUT_DIR":/out:Z \
    docker.io/hugomods/hugo:latest \
    hugo --minify --source /src --destination /out
  ```

`build.sh` defaults to host hugo and falls back to (or can be flagged into) the podman
one-shot. Deploy = run `build.sh` on the host (manually, or from a git pull + systemd
timer the user wires up later — out of scope for v1).

### Runtime — Podman Quadlet

`deploy/igou-io.container` (installed to `/etc/containers/systemd/` for rootful, or
`~/.config/containers/systemd/` for rootless; `systemctl daemon-reload` generates the
service). Mounts the served directory read-only — nginx:alpine already serves
`/usr/share/nginx/html` on port 80 with a sane default config, so no custom nginx.conf
is needed for v1:

```ini
[Unit]
Description=igou.io static site
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/library/nginx:alpine
PublishPort=8080:80
Volume=/srv/www/igou.io:/usr/share/nginx/html:ro,Z

[Service]
Restart=always

[Install]
WantedBy=default.target
```

The served path (`/srv/www/igou.io`) and host port (`8080`) are placeholders the user
adjusts to fit their host / reverse proxy.

### CI — `.github/workflows/master.yml` (build-verification only)

On push / PR / `workflow_dispatch`: checkout, install Hugo (pinned version, e.g.
`peaceiris/actions-hugo`), run `hugo --minify`, fail on errors. This is a sanity check
that the site builds — it does **not** deploy and needs no secrets. Entirely optional;
can be dropped if the user prefers zero CI.

## Cleanup

- Remove the abandoned mkdocs migration: `mkdocs.yml`, `docs/index.md`, `docs/blog/`.
  (The `docs/superpowers/` specs subtree stays.)
- Remove `old/` entirely (the old Jekyll site + its vulnerable `Gemfile.lock`); the
  splash image pool was copied into `assets/home/` beforehand so nothing is lost.
- Update `.gitignore` to ignore Hugo build output (`/public/`, `/resources/`,
  `.hugo_build.lock`).

## Testing / verification

- `hugo --minify` builds with no errors/warnings; `public/` is produced.
- Manual: `hugo server` renders the centered splash (image + name + `blog / about /
  github / contact` links), the `/blog/` list, the starter post (with highlighted
  code), `/about/`, and `/contact/` — all dark.
- Confirm **no `<script>` tags** in any built HTML (splash image is static, not JS).
- Confirm RSS (`/index.xml`) and `/sitemap.xml` exist.
- `deploy/build.sh` writes the built site into a target dir; pointing a stock
  `nginx:alpine` container at that dir and `curl`-ing it returns the homepage.

## Non-goals

- No client-side JS, no analytics/trackers, no comments, no web fonts.
- No migration of old posts (archived only).
- No custom container image and no registry — a stock `nginx:alpine` serves
  host-built files.
