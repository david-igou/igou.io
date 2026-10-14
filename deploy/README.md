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
publication job and nightly schedule are retirement targets in the Kubernetes
migration; the production Quadlet has been removed from this repository.

## Local serving and export

For development, run Hugo locally from the repository root:

```sh
hugo server --bind 127.0.0.1
```

Use the Hugo version pinned by CI. To export static files through the existing
container helper, run `./deploy/build.sh /path/to/output`. Production publication
uses the CI/image/GitOps flow above.

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
