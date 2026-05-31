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
| Old posts | **Start fresh.** Keep `old/` in the repo as an unpublished archive; do not migrate |
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
archetypes/default.md        # template used by `hugo new posts/<name>.md`
content/
  _index.md                  # homepage intro copy
  about.md                   # short about / contact page
  posts/
    hello-world.md           # one starter post (demonstrates code block + frontmatter)
layouts/
  _default/baseof.html       # HTML shell: <head>, header (name + GitHub link), footer
  _default/single.html       # a single post
  _default/list.html         # generic section listing (e.g. /posts/)
  index.html                 # homepage: intro + reverse-chron post list
static/
  css/style.css              # the one stylesheet (dark-only)
deploy/
  igou-io.container          # Podman Quadlet unit (stock nginx:alpine + volume mount)
  build.sh                   # build the site into the served dir (host hugo or podman one-shot)
  README.md                  # one-time setup notes (quadlet install, paths)
.github/workflows/master.yml # build-verification only (no deploy)
```

## Authoring flow

- `hugo new posts/my-title.md` scaffolds frontmatter from `archetypes/default.md`,
  or simply create the markdown file by hand.
- Frontmatter: `title` (string), `date` (ISO date), optional `tags` (list).
- `draft: true` keeps a post out of the build until ready.
- Write markdown, commit, push to `master` → CI builds and publishes.

## Pages & URLs

- `/` — homepage: brief intro + reverse-chronological list of posts (title + date).
- `/posts/<slug>/` — individual posts.
- `/about/` — short about/contact page.
- `/index.xml` — RSS feed (Hugo built-in, generated at build, zero JS).
- `/sitemap.xml` — sitemap (Hugo built-in).

Out of scope for v1 (YAGNI; trivial to add later): tag/category pages, pagination,
client-side search, comments, analytics.

## Styling (dark-only)

- A single dark palette defined with CSS custom properties at the top of `style.css`.
- System font stacks; readable measure (max content width ~ 40–46rem, centered).
- Minimal, semantic HTML. Visible focus styles and adequate contrast for accessibility.
- Chroma dark highlight style configured in `hugo.toml` (`markup.highlight`), emitted
  as inline classes/styles at build time.

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
- Leave `old/` untouched as the historical archive (not built, not published).
- Update `.gitignore` to ignore Hugo build output (`/public/`, `/resources/`,
  `.hugo_build.lock`).

## Testing / verification

- `hugo --minify` builds with no errors/warnings; `public/` is produced.
- Manual: `hugo server` (or open built `public/index.html`) renders homepage, the
  starter post (with highlighted code), and `/about/` in a dark theme.
- Confirm **no `<script>` tags** in any built HTML.
- Confirm RSS (`/index.xml`) and `/sitemap.xml` exist.
- `deploy/build.sh` writes the built site into a target dir; pointing a stock
  `nginx:alpine` container at that dir and `curl`-ing it returns the homepage.

## Non-goals

- No client-side JS, no analytics/trackers, no comments, no web fonts.
- No migration of old posts (archived only).
- No custom container image and no registry — a stock `nginx:alpine` serves
  host-built files.
