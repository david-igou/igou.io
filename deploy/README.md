# Deploy

The site is built with the Hugo version pinned in `.github/workflows/master.yml`
and packaged in an unprivileged nginx image. CI checks pull requests and publishes
successful merged `master` builds to the existing public repository
`quay.io/igou/igou.io`, using `vps` and `vps-<commit>` tags.

Production deployment is an immutable digest in
`igou-kubernetes/clusters/vps/applications/igou-io/`. OpenShift Argo CD
reconciles the VPS deployment, and Renovate updates its pinned `vps` digest.
The VPS pulls the image anonymously and does not build Hugo or need a registry
credential. The `www.igou.io` redirect is a Gateway HTTPRoute in that cluster.

The commands below describe local build/export work only. The former AAP
publication job, nightly schedule, and production Quadlet are retired by the
Kubernetes migration.

## Local serving and export

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

Public TLS and hostname routing are managed by cert-manager and NGINX Gateway
Fabric through the VPS GitOps manifests. Host lifecycle maintenance remains in
AAP; site publication uses the CI/image/GitOps path above.
