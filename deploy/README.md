# Deploy

The site is plain static files served by a stock `nginx:alpine` container. There is no
custom image and no registry — the host builds this repo with Hugo and nginx serves the
output directory.

## One-time setup

1. Pick a served directory (default `/srv/www/igou.io`) and create it.
2. Install the Quadlet unit so systemd manages the nginx container:
   - rootful: copy `igou-io.container` to `/etc/containers/systemd/`
   - rootless: copy it to `~/.config/containers/systemd/`
3. Reload + start:
   ```sh
   systemctl daemon-reload          # or: systemctl --user daemon-reload
   systemctl start igou-io          # or: systemctl --user start igou-io
   ```
   nginx now serves the directory on host port `8080` (adjust `PublishPort` /
   `Volume` in the unit to taste).

## Publishing / updating content

Build straight into the served directory:

```sh
./deploy/build.sh /srv/www/igou.io
```

nginx serves files live, so a rebuild is the deploy — no container restart needed.
Wire `build.sh` to a git pull + systemd timer if you want it automatic.

## Search indexing

The shared HTML template emits each page's absolute canonical URL from Hugo's
`baseURL`. The homepage description comes from `params.description` in
`hugo.toml`; other pages use front matter `description`, falling back to their
plain-text summary. Add a specific description when publishing a post:

```yaml
---
title: Example post
description: A short summary of what readers will learn.
draft: false
---
```

`layouts/robots.txt` allows crawling and advertises the generated sitemap.
Submit `https://igou.io/sitemap.xml` in Google Search Console and Bing Webmaster
Tools after verifying site ownership. Verification and submission are separate
from deployment; these templates cannot guarantee indexing.

The VPS publishes merged `master` through AAP's `deploy_static_site` job template
(also scheduled nightly). The `www.igou.io` redirect is managed separately by
`igou-inventory` and `igou-ansible`, applied through `podman_quadlets`.
