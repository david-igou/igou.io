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
| Deployment | **Podman Quadlet** (systemd unit) running an `nginx:alpine` image pulled from Quay |
| Branding | **Minimal** — name "David Igou" + a GitHub link, no tagline |
| Container build | Single-arch `nginx:alpine` serving static files (drop the old prometheus exporter sidecar and multi-arch matrix) |

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
Dockerfile                   # nginx:alpine, COPY public/ -> /usr/share/nginx/html
deploy/
  igou-io.container          # Podman Quadlet unit
.github/workflows/master.yml # build + push pipeline (rewritten)
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

### Container

`Dockerfile` (single-arch):

```dockerfile
FROM nginx:alpine
COPY public/ /usr/share/nginx/html/
```

(Hugo output dir is `public/`. nginx:alpine already serves on port 80 with a sane
default config; no custom nginx.conf required for v1.)

### CI — `.github/workflows/master.yml` (rewritten)

On push to `master` (and `workflow_dispatch`):

1. Checkout.
2. Install Hugo (pinned version) — e.g. `peaceiris/actions-hugo` or direct download.
3. `hugo --minify` → produces `public/`.
4. Build the image from `Dockerfile`.
5. Log in to Quay (`QUAY_LOGIN` / `QUAY_PASSWORD` secrets, already present) and push
   `quay.io/igou/igou.io:latest`. Single-arch (`linux/amd64` by default; switch to
   `arm64` or add a second platform only if the target host needs it).

No prometheus exporter, no multi-arch matrix, no artifact hand-off between jobs.

### Runtime — Podman Quadlet

`deploy/igou-io.container` (installed to `/etc/containers/systemd/` for rootful, or
`~/.config/containers/systemd/` for rootless; `systemctl daemon-reload` generates the
service):

```ini
[Unit]
Description=igou.io static site
After=network-online.target
Wants=network-online.target

[Container]
Image=quay.io/igou/igou.io:latest
PublishPort=8080:80
AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=default.target
```

`AutoUpdate=registry` lets `podman auto-update` (timer) pull a freshly-pushed `:latest`
and restart the unit. The published host port (`8080`) is a placeholder the user can
adjust to fit their reverse proxy / ingress.

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
- `podman build` of the Dockerfile succeeds and `curl` against the running container
  returns the homepage.

## Non-goals

- No client-side JS, no analytics/trackers, no comments, no web fonts.
- No migration of old posts (archived only).
- No multi-arch image unless explicitly required by the deploy host.
