# smarthome

Installs home automation: Home Assistant, Mosquitto, Zigbee2MQTT and Matterbridge. It needs [addons](../addons/).

## Configure

Create `values.local.yaml`:

```yaml
global:
  nfs:
    server: 192.168.x.x               # NAS for the backups

home-assistant:
  hostnames:                          # lists are replaced, not merged: keep the local one too
    - home-assistant.smarthome.local
    - ha.example.com
  secrets:                            # becomes Home Assistant's secrets.yaml
    latitude_home: 0.0
    longitude_home: 0.0
    latitude_work: 0.0
    longitude_work: 0.0
    external_url: https://ha.example.com
    internal_url: http://home-assistant.smarthome.local
    trusted_networks:
      - 192.168.x.0/24

zigbee2mqtt:
  adapter:
    port: tcp://192.168.x.x:6638      # network Zigbee coordinator
    type: ember
  backup:
    nfsPath: /path/to/backups/zigbee2mqtt

matterbridge:
  backup:
    nfsPath: /path/to/backups/matterbridge
```

No secret has to be created by hand: the MQTT passwords for `homeassistant` and `zigbee2mqtt` are generated in the Secret `mosquitto-users`.

## Deploy

```bash
moon run smarthome:template
moon run smarthome:deploy
```

Then, in the web UIs:

- **Home Assistant**: add the MQTT integration with broker `mosquitto`, user `homeassistant` and the password from:

  ```bash
  kubectl -n smarthome get secret mosquitto-users -o jsonpath='{.data.homeassistant}' | base64 -d
  ```

- **Matterbridge**: install the Home Assistant plugin and give it a long-lived token created in Home Assistant.

## Day to day

- **Change the Home Assistant configuration**: edit `charts/home-assistant/files/` (`configuration.yaml`, `integrations/`, `lovelace/`), then build and update; Home Assistant restarts with the new files.
  Automations, scripts and scenes are edited from the UI and live on the volume, not in this folder.
- **Backups**: Home Assistant's own automatic backups, set from the UI (Settings → System → Backups) with a WebDAV location; they are not part of the chart. Keep the encryption key outside the cluster: without it the backups cannot be restored.
- **Zigbee2MQTT backups**: a CronJob asks Zigbee2MQTT for its own backup every night and keeps the last `backup.retention` zips. To restore, scale `zigbee2mqtt` to 0, unzip the backup into its volume from a temporary pod, then scale it back to 1.
- **Matterbridge backups**: a CronJob runs matterbridge's own backup every night and keeps the last `backup.retention` zips. If you set a password in the matterbridge frontend, store it in the Secret `matterbridge-frontend` (key `password`), or the backup stops. To restore, scale `matterbridge` to 0, unzip the backup into its volume from a temporary pod, then scale it back to 1.
- **Restore a Home Assistant backup**: the config files are mounted read-only, so a restore from the UI fails. Scale the deployment to 0 and extract the backup from a temporary pod that mounts only the volume.
