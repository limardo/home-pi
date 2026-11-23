const fs = require('fs');
const http = require('http');
const path = require('path');
const WebSocket = require('/usr/local/lib/node_modules/matterbridge/node_modules/ws');

const host = process.env.MATTERBRIDGE_HOST;
const dir = '/backup';
const keep = Number(process.env.RETENTION);
const name = `matterbridge-${new Date().toISOString().slice(0, 10)}.zip`;
const requested = Date.now();

const fail = (message) => {
  console.error(`FAILED ${message}`);
  process.exit(1);
};
setTimeout(() => fail('backup not ready in time'), 180000);

const get = () =>
  new Promise((resolve, reject) => {
    http
      .get(`http://${host}/api/download-backup`, (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolve({ res, body: Buffer.concat(chunks) }));
      })
      .on('error', reject);
  });

// matterbridge answers before the zip is written: wait for a fresh and complete archive
const download = async () => {
  for (;;) {
    const { res, body } = await get();
    const modified = Date.parse(res.headers['last-modified'] ?? '');
    const complete = body.subarray(-65557).includes(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
    if (res.statusCode === 200 && modified >= requested - 60000 && complete) return body;
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
};

const save = (body) => {
  const file = path.join(dir, name);
  fs.writeFileSync(`${file}.tmp`, body);
  fs.renameSync(`${file}.tmp`, file);
  console.log(`ok ${name} ${body.length} bytes`);
  // A failed run exits before this point, so it never prunes complete backups
  fs.readdirSync(dir)
    .filter((f) => /^matterbridge-\d{4}-\d{2}-\d{2}\.zip$/.test(f))
    .sort()
    .reverse()
    .slice(keep)
    .forEach((f) => {
      fs.unlinkSync(path.join(dir, f));
      console.log(`removed ${f}`);
    });
};

const password = encodeURIComponent(process.env.MATTERBRIDGE_PASSWORD ?? '');
const ws = new WebSocket(`ws://${host}/?password=${password}`);
ws.on('error', (error) => fail(error.message));
ws.on('open', () => {
  ws.send(JSON.stringify({ id: 1, src: 'Frontend', dst: 'Matterbridge', method: '/api/create-backup', params: {} }));
});
ws.on('message', async (raw) => {
  const message = JSON.parse(raw);
  if (message.id !== 1) return;
  if (!message.success) fail(message.error ?? 'create-backup refused');
  try {
    save(await download());
  } catch (error) {
    fail(error.message);
  }
  ws.close();
  process.exit(0);
});
