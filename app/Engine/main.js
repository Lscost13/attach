// Точка входа ядра: поднимаем сам DeepSeek Harness внутри процесса Node.
// DSH сам слушает 127.0.0.1 и печатает адрес с токеном — мы его перехватываем
// и кладём в engine.json, чтобы SwiftUI знал, куда стучаться.

const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const engineDir = process.env.ATTACH_ENGINE || __dirname;
const home = process.env.HOME || engineDir;
const stateDir = path.join(home, '.attach');
const stateFile = path.join(stateDir, 'engine.json');

fs.mkdirSync(stateDir, { recursive: true });

function publish(url) {
  let token = '';
  try {
    token = new URL(url).searchParams.get('token') || '';
  } catch {}
  const payload = {
    url,
    token,
    node: process.version,
    at: new Date().toISOString(),
  };
  fs.writeFileSync(stateFile, JSON.stringify(payload));
  console.log('[attach] engine published to', stateFile);
}

let seen = false;
const write = process.stdout.write.bind(process.stdout);
process.stdout.write = function (chunk, ...rest) {
  try {
    if (!seen) {
      const text = typeof chunk === 'string' ? chunk : String(chunk);
      const match = text.match(/dsh web:\s*(https?:\/\/\S+)/);
      if (match) {
        seen = true;
        publish(match[1]);
      }
    }
  } catch {}
  return write(chunk, ...rest);
};

async function main() {
  const pkgPath = require.resolve('@deepseek-ai/dsh/package.json');
  const pkg = require(pkgPath);
  const root = path.dirname(pkgPath);
  const bin = typeof pkg.bin === 'string' ? pkg.bin : pkg.bin && pkg.bin.dsh;
  if (!bin) throw new Error('dsh: в пакете нет bin');

  const binPath = path.join(root, bin);
  process.env.DSH_HOME = process.env.DSH_HOME || path.join(home, '.dsh');

  process.argv = [
    process.argv[0],
    binPath,
    'web',
    '--no-open',
    '--host',
    '127.0.0.1',
    '--port',
    '3080',
  ];

  console.log('[attach] booting dsh:', binPath);
  const mod = await import(pathToFileURL(binPath).href);
  await mod.runCli();
}

main().catch((err) => {
  console.error('[attach] dsh failed:', (err && (err.stack || err.message)) || err);
  process.exitCode = 1;
});
