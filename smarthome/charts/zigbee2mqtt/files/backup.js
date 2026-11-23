const fs = require('fs');
const path = require('path');
const mqtt = require('/app/node_modules/mqtt');

const dir = '/backup';
const keep = Number(process.env.RETENTION);
const name = `zigbee2mqtt-${new Date().toISOString().slice(0, 10)}.zip`;

const fail = (message) => {
  console.error(`FAILED ${message}`);
  process.exit(1);
};
setTimeout(() => fail('no answer from zigbee2mqtt'), 120000);

const client = mqtt.connect(process.env.MQTT_SERVER, {
  username: process.env.MQTT_USER,
  password: process.env.MQTT_PASSWORD,
});
client.on('error', (error) => fail(error.message));
client.on('connect', () => {
  client.subscribe('zigbee2mqtt/bridge/response/backup', (error) => {
    if (error) fail(error.message);
    client.publish('zigbee2mqtt/bridge/request/backup', '{}');
  });
});
client.on('message', (_topic, payload) => {
  const response = JSON.parse(payload);
  if (response.status !== 'ok') fail(response.error);
  const file = path.join(dir, name);
  fs.writeFileSync(`${file}.tmp`, Buffer.from(response.data.zip, 'base64'));
  fs.renameSync(`${file}.tmp`, file);
  console.log(`ok ${name} ${fs.statSync(file).size} bytes`);
  // A failed run exits above, so it never prunes complete backups
  fs.readdirSync(dir)
    .filter((f) => /^zigbee2mqtt-\d{4}-\d{2}-\d{2}\.zip$/.test(f))
    .sort()
    .reverse()
    .slice(keep)
    .forEach((f) => {
      fs.unlinkSync(path.join(dir, f));
      console.log(`removed ${f}`);
    });
  client.end(false, () => process.exit(0));
});
