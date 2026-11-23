# datastores

Installs the shared databases: a three-instance PostgreSQL cluster (CloudNativePG) with nightly backups to NFS. It needs [addons](../addons/), which installs the operator.

## Configure

Create `values.local.yaml`:

```yaml
global:
  nfs:
    server: 192.168.x.x

postgresql:
  backup:
    nfsPath: /path/to/postgresql   # one folder per day, one dump per database
```

Schedule and retention are `postgresql.backup.schedule` and `postgresql.backup.retentionDays` in `charts/postgresql/values.yaml`.

## Deploy

```bash
moon run datastores:template
moon run datastores:deploy
```

Apps connect to `postgresql-rw.datastores.svc:5432`.

## Day to day

- **Give an app a database**: declare it in the app's own chart, with a CNPG `DatabaseRole` and `Database` in the `datastores` namespace (see `apps/templates/_servarr.tpl`). A user can only reach databases named after one of its roles.
- **Open a SQL shell**:

  ```bash
  kubectl -n datastores exec -it postgresql-1 -- psql
  ```

- **Restore a database** from a dump on the NFS share:

  ```bash
  kubectl -n datastores cp <db>.dump <primary pod>:/tmp/<db>.dump
  kubectl -n datastores exec -it <primary pod> -- pg_restore --clean -d <db> /tmp/<db>.dump
  kubectl -n datastores exec <primary pod> -- rm /tmp/<db>.dump
  ```

  The primary is the pod with `role=primary`: `kubectl -n datastores get pods -l role=primary`.
