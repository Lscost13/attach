// Ядро Attach. Запускается внутри Node 24 (nodejs-mobile) в песочнице приложения.
// Пока умеет только жить и отвечать на /health — дальше здесь появится агент.

const http = require('http');
const os = require('os');
const path = require('path');

const port = Number(process.env.ATTACH_PORT || 8787);
const engineDir = process.env.ATTACH_ENGINE || __dirname;
const workDir = process.env.ATTACH_WORKDIR || os.homedir();

function json(res, code, body) {
  const data = JSON.stringify(body);
  res.writeHead(code, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(data),
  });
  res.end(data);
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    return json(res, 200, {
      ok: true,
      node: process.version,
      platform: process.platform,
      arch: process.arch,
      engine: engineDir,
      workdir: workDir,
      uptime: Math.round(process.uptime()),
    });
  }
  json(res, 404, { error: 'not found' });
});

server.on('error', (err) => {
  console.error('[attach] server error:', err && err.message);
});

server.listen(port, '127.0.0.1', () => {
  console.log('[attach] core ready on 127.0.0.1:' + port + ' node ' + process.version);
});
