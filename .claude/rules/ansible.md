# Ansible rules

## Files
- YAML files use `.yaml`, except `galaxy.yml` and `meta/runtime.yml`, whose names ansible-core hardcodes.

## Inventory
- The real inventory is git-ignored: every host, address, user, disk and private value lives only there.
- `inventories/example/` is tracked, with the same groups and variables as the real one and placeholders for every private value (`192.168.x.x`, `/dev/<disk>`, `<user>`).
- `check` and `deploy` use the real inventory; `lint` and `test` use the example and must pass on placeholders.

## Roles
- Roles live in `roles/`; a role moves into a `luclim.*` collection only when it grows into a group of related roles.
- No home-specific value in tasks, templates or files: users, timezone, paths and addresses are variables. Group names and k0s worker profile names are not private.
- Every variable a role reads is declared in its `meta/argument_specs.yaml`; the ones with a default also have it in `defaults/main.yaml`. Private values have no default and are `required`.
- Variables are prefixed with the role name (`os_timezone`, `worker_profile`).

## Tasks
- `--check` works on a host never provisioned: a task that needs a tool the role itself installs is skipped in check mode or ignores its errors there.
- ansible-lint with the `production` profile passes with 0 errors; a rule is excluded only in the lint config, with a one-line reason.

## Secrets
- No credential in any tracked file: secrets live in the real inventory or in `secrets/`, both git-ignored.
- Every task that reads or writes a secret has `no_log: true`.

## Comments
- English only, and only where the code would otherwise be changed wrongly. No section headers or history.
