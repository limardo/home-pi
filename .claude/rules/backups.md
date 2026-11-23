# Backup rules

- Every backup lands on the NAS, under a folder named `backups` (any case); no copy ever leaves the NAS, neither offsite nor cloud.
- An app's own backup system comes first (Home Assistant backups, *arr backups, k0s backup...); a volume-level backup is the fallback for apps without one.
- Retention keeps at least 3 backups or 7 days.
- Databases are dumped as compressed plain SQL (`.sql.gz`), never in a binary format.
- Backup paths on the NAS are private values: they live only in `values.local.yaml` or in the inventory.
