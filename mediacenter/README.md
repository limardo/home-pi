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
  backup:
    nfsPath: /path/to/backups/tvheadend

jellyfin:
  config:
    persistence:
      media:
        nfsPath: /path/to/media
  backup:
    nfsPath: /path/to/backups/jellyfin

navidrome:
  nfs:
    musicPath: /path/to/music
  backup:
    nfsPath: /path/to/backups/navidrome
```

tvheadend and Jellyfin run on the x86 node by default, for transcoding.

The guide sources for tvheadend are `epg.urls` in `charts/tvheadend/values.yaml`.

Jellyfin needs an API key for its nightly backup: create one in Dashboard → API Keys and store it in the Secret `jellyfin-backup-apikey` (key `token`) in the `mediacenter` namespace.

## Deploy

```bash
moon run mediacenter:template
moon run mediacenter:deploy
```

## Day to day

- **Jellyfin backups**: a CronJob runs Jellyfin's own backup every night (database, settings, subtitles; no metadata) into the backup folder and keeps the last `backup.retention` archives. Restore from Dashboard → Backups, which lists the same folder. The Playback Reporting plugin has its own backup: set its backup path to a subfolder of `/config/data/backups`.
- **tvheadend backups**: tvheadend saves its config only when its version changes, so a CronJob archives it every night (without image cache and EPG data) and keeps the last `backup.retention` archives. To restore, scale `tvheadend` to 0, extract the archive into its config folder, then scale it back to 1.
- **Navidrome backups**: Navidrome backs up its database by itself on `backup.schedule`, keeping `backup.count` copies. To restore, scale `navidrome` to 0 and run `navidrome backup restore --backup-file /backups/<file>` from a pod with the same volumes.
- **Upgrade Jellyfin**: it is installed from its upstream chart, so change `version` in `charts/jellyfin/values.yaml` instead of `appVersion`, then build and update.
