# platform

Prepares the boards and installs a k0s cluster on them with Ansible.

## Configure

Create your inventory from the example:

```bash
cp -r inventories/example inventories/home
```

In `inventories/home/hosts`, list your machines in the `minipc`, `raspberry` and `banana` groups, then pick one controller and the workers:

```ini
[banana]
192.168.x.3 hostname_name=banana-1 os_data_disk=/dev/<disk>

[k0s_controller]
192.168.x.4

[k0s_worker]
192.168.x.3 worker_profile=bpi-m5
```

| Variable | Set in | Meaning |
|---|---|---|
| `ansible_user` | `group_vars/all.yaml` | SSH user on the boards, with sudo |
| `os_timezone` | `group_vars/all.yaml` | Timezone (default `Etc/UTC`) |
| `os_release_upgrade` | `group_vars/all.yaml` | `true` to allow distribution release upgrades |
| `k0s_version` | `group_vars/all.yaml` | k0s version to install |
| `hostname_name` | host | Hostname to set |
| `os_data_disk` | host | Optional disk to format and mount for Longhorn |
| `os_data_disk_mount` | host | Its mount point (default `/srv/data`) |
| `os_cpu_max_freq` | host | Optional CPU frequency cap in kHz (default `0`, no cap) |
| `worker_profile` | `k0s_worker` host | k0s worker profile, defined in `luclim/k0s/roles/controller/templates/k0s.yaml.j2` |
| `backup_nfs_server` / `backup_nfs_path` | `group_vars/k0s_controller.yaml` | NFS share for the nightly `k0s backup` of the controller |
| `backup_schedule` / `backup_retention` | `group_vars/k0s_controller.yaml` | systemd `OnCalendar` (default 02:30) and archives kept (default 7, at least 3) |

## Deploy

```bash
moon run platform:build    # install the Ansible collections
moon run platform:check    # dry run, shows what would change
moon run platform:deploy   # provision the boards and install k0s
```

Fetch the kubeconfig from the controller to use `kubectl` and the Helm projects:

```bash
mkdir -p ~/.kube
ssh <user>@<controller> sudo k0s kubeconfig admin > ~/.kube/config
chmod 600 ~/.kube/config
```

It grants full admin access to the cluster: keep it out of the repository.

## Day to day

- **Add a board**: add it to the inventory and to `k0s_worker`, then run `check` and `deploy`.
- **Upgrade k0s**: change `k0s_version`, then run `check` and `deploy`.
- **Change the cluster configuration** (worker profiles, MetalLB, Prometheus): edit `k0s.yaml.j2`, then `deploy`.
- **Back up the cluster**: the controller runs `k0s backup` every night (timer `k0s-backup.timer`), mounting the NFS share only for the backup. Run one now with `sudo systemctl start k0s-backup.service`; restore on a clean controller with `k0s restore <archive>`.
- **ansible-lint fails on commit**: `moon run platform:fix` fixes what it can.
