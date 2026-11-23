# apps

Installs self-hosted apps: radarr, sonarr, lidarr, prowlarr, configarr, flaresolverr, slskd and soulsync. It needs [addons](../addons/) and [datastores](../datastores/): the *arr apps store their data in the shared PostgreSQL.

## Configure

Create `values.local.yaml` with the NFS folders of each app:

```yaml
global:
  nfs:
    server: 192.168.x.x

radarr:
  nfs:
    config:
      path: /path/to/radarr
    movies:
      path: /path/to/movies
    downloads:
      path: /path/to/downloads
# sonarr (tv), lidarr (music) and prowlarr (config only) follow the same shape

slskd:
  nfs:
    downloadsPath: /path/to/downloads

soulsync:
  nfs:
    downloadsPath: /path/to/downloads
    musicPath: /path/to/music

configarr:
  downloadClient:
    host: 192.168.x.x                 # download client used by radarr and sonarr
    remotePath: /path/on/the/client/   # mapped to the local downloads folder
  repos:
    path: /path/to/configarr           # git cache of TRaSH Guides
```

## Secrets

Create these in the `apps` namespace before deploying. Write each one's keys in an env file (`KEY=value`, one per line) outside the repository, so the values stay out of your shell history:

| Secret | Keys |
|---|---|
| `slskd-secrets` | `SLSKD_SLSK_USERNAME`, `SLSKD_SLSK_PASSWORD`, `SLSKD_USERNAME`, `SLSKD_PASSWORD`, `SLSKD_API_KEY` |
| `jellyfin-apikey` | `token`: an API key created in Jellyfin |

```bash
kubectl create namespace apps
kubectl -n apps create secret generic slskd-secrets --from-env-file=<file>
kubectl -n apps create secret generic jellyfin-apikey --from-env-file=<file>
```

Optional: `configarr-secrets`, with a `secrets.yml` key for the parts of the prowlarr configuration that are not in `charts/configarr/files/`. Without it, those parts are left as they are.

API keys and database passwords of the *arr apps are generated on the first install and kept across upgrades.

## Deploy

```bash
moon run apps:template
moon run apps:deploy
```

## Day to day

- **Read an app's API key**:

  ```bash
  kubectl -n apps get secret radarr-apikey -o jsonpath='{.data.token}' | base64 -d
  ```

- **Change the *arr configuration** (quality profiles, custom formats, download client, indexers): edit the files in `charts/configarr/files/`, build and update. configarr applies them every night; to apply them now:

  ```bash
  kubectl -n apps create job configarr-now --from=cronjob/configarr
  ```

- **Upgrade TRaSH Guides**: change `trashRevision` in `charts/configarr/values.yaml`, then build and update.
- **Remove the project**: `destroy` keeps the *arr databases in datastores, as well as the volumes.
