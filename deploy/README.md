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
