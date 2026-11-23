# Helm chart rules

## Values
- Stack values (hostnames, gateway, `enabled`, `nodeSelector`, `tolerations`) live in the root `values.yaml`.
- Private values (NAS IP, NFS paths, internal hosts) live only in `values.local.yaml`, ignored by git and Helm. They are absent from the root `values.yaml`, not placeholders there.
- Subchart `values.yaml` holds only placeholders for stack values (`192.168.x.x`, `/path/to/...`, `<app>.example.local`) plus app defaults (image, ports, resources, probes, settings).
- Write full paths per app, with no `basePath` concatenation.
- moon `template`/`deploy`/`update` pass `--values=values.yaml --values=values.local.yaml`; `lint` runs without the local file and must pass on placeholders.

## Scheduling
- Every subchart with a pod has `nodeSelector: {}` and `tolerations: []` in its values, both required by its schema, rendered with `toYaml`. Moving an app to another node is a root-values change only.
- Templates render `nodeSelector` and `tolerations` inside `{{- with }}`, so empty values omit the key: operators such as CNPG compare `[]`/`{}` with their stored `nil` and recreate the pods forever.

## Schemas
- Each subchart has a `values.schema.json` with `additionalProperties: false` and `required` for every key the templates read.

## Templates
- Service, HTTPRoute and PVC come from the shared helpers in `templates/_helpers.tpl`, included in one line.
- Images whose entrypoint drops privileges by `PUID`/`PGID` (linuxserver and alike) get `PUID`/`PGID` 1000 and `TZ` Europe/Rome; other images run as 1000:1000 through `securityContext` (`fsGroup` included).
- Every app ships its blackbox Probe (`probe.url`, rendered with `tpl`).
- `startupProbe` gates the other probes: no `initialDelaySeconds`.

## Lifecycle on uninstall
- PVCs keep `helm.sh/resource-policy: keep`: they hold data.
- Secrets never get `keep`: an uninstall must remove them.
- CNPG `Database` and `DatabaseRole` use `databaseReclaimPolicy`/`databaseRoleReclaimPolicy: retain`: the data stays in Postgres.

## Secrets
- No credential in any chart file.
- Generated values (apikeys, DB passwords) are created by the chart and kept with `lookup`.
- Values Helm cannot own are applied by hand from `secrets/`, git-ignored.

## Comments
- English only, and only where the code would otherwise be changed wrongly. No section headers, per-define descriptions or history.
