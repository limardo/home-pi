# mediacenter

Installs Live TV and media playback: tvheadend, Jellyfin and Navidrome. It needs [addons](../addons/).

## Configure

Create `values.local.yaml` with the NFS folders of your media:

```yaml
global:
  nfs:
    server: 192.168.x.x

tvheadend:
  nfs:
    path: /path/to/tvheadend
    piconsPath: /path/to/picons

jellyfin:
  config:
    persistence:
      media:
        nfsPath: /path/to/media

navidrome:
  nfs:
    musicPath: /path/to/music
```

tvheadend and Jellyfin run on the x86 node by default, for transcoding.

The guide sources for tvheadend are `epg.urls` in `charts/tvheadend/values.yaml`.

## Deploy

```bash
moon run mediacenter:template
moon run mediacenter:deploy
```

## Day to day

- **Upgrade Jellyfin**: it is installed from its upstream chart, so change `version` in `charts/jellyfin/values.yaml` instead of `appVersion`, then build and update.
