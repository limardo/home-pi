# smarthome

Installs home automation: Home Assistant, Mosquitto, Zigbee2MQTT and Matterbridge. It needs [addons](../addons/).

## Configure

Create `values.local.yaml`:

```yaml
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
- **Restore a Home Assistant backup**: the config files are mounted read-only, so a restore from the UI fails. Scale the deployment to 0 and extract the backup from a temporary pod that mounts only the volume.
