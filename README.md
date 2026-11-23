# home-pi

A Kubernetes homelab for home automation and media, built on ARM single-board computers and an x86 mini PC.

The cluster runs [k0s](https://k0sproject.io). Everything, from the operating system of the boards to the apps, is described in this repository and driven by [moon](https://moonrepo.dev).

## Projects

| Project | Tool | What it does |
|---|---|---|
| [platform](platform/) | Ansible | Prepares the boards and installs the k0s cluster |
| [addons](addons/) | Helm | Cluster services: ingress, certificates, policies, storage, database operators, observability |
| [datastores](datastores/) | Helm | Shared databases (a PostgreSQL cluster) |
| [mediacenter](mediacenter/) | Helm | Live TV and media playback (tvheadend, Jellyfin, Navidrome) |
| [apps](apps/) | Helm | Self-hosted apps, including the *arr suite |
| [smarthome](smarthome/) | Helm | Home Assistant, Mosquitto, Zigbee2MQTT, Matterbridge |

Each project has its own README with its configuration and commands.

```
platform
  └─► addons
        ├─► datastores
        ├─► mediacenter
        ├─► smarthome
        └─► apps (also needs datastores)
```

## Requirements

- [moon](https://moonrepo.dev/docs/install) and [uv](https://docs.astral.sh/uv/): moon uses uv to install Python, Ansible and the linters from `pyproject.toml`
- [Helm](https://helm.sh) 3, [kubectl](https://kubernetes.io/docs/tasks/tools/) and [yq](https://github.com/mikefarah/yq)
- SSH access to the boards, and an NFS server for the media and backups

## Getting started

```bash
git clone <this repository> && cd home-pi
uv sync
uv run pre-commit install
```

Configure each project as its README explains: an inventory for `platform`, a `values.local.yaml` for each Helm project. Then deploy them in dependency order:

```bash
moon run platform:deploy
moon run addons:deploy
moon run datastores:deploy
moon run mediacenter:deploy
moon run smarthome:deploy
moon run apps:deploy
```

## Common tasks

Every Helm project has the same moon tasks:

| Task | Command |
|---|---|
| `template` | `helm template`, to inspect the manifests |
| `lint` | `helm lint` |
| `format` | `yamlfmt` on the changed files |
| `build` | `helm package` |
| `deploy` | `helm install` |
| `update` | `helm upgrade` of the packaged chart: run `build` first, in a separate `moon run` |
| `destroy` | `helm uninstall` |

In every Helm project's root `values.yaml` you choose, per app:

- `enabled`: install it or not
- `hostnames`: the names it answers on through the gateway
- `nodeSelector` and `tolerations`: the node it runs on

Day to day:

- **Apply a change** (values, files, versions): build, then update.

  ```bash
  moon run <project>:build
  moon run <project>:update
  ```

- **Upgrade an app**: change `appVersion` in `charts/<app>/Chart.yaml`, then build and update.
- **Move an app to another node**: change its `nodeSelector` and `tolerations`, then build and update.
- **Remove a project**: `moon run <project>:destroy`. Volumes are kept.

On commit, pre-commit formats the staged files and runs gitleaks, yamllint, ansible-lint and `helm lint` on the affected projects.

## License

[MIT](LICENSE)
