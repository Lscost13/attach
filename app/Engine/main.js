// Точка входа ядра: поднимаем сам DeepSeek Harness внутри процесса Node.
// Своего сервера здесь больше нет — DSH сам слушает 127.0.0.1:3080.

const path = require('path');
const { pathToFileURL } = require('url');

const engineDir = process.env.ATTACH_ENGINE || __dirname;
const home = process.env.HOME || engineDir;

async function main() {
  const pkgPath = require.resolve('@deepseek-ai/dsh/package.json');
  const pkg = require(pkgPath);
  const root = path.dirname(pkgPath);
  const bin = typeof pkg.bin === 'string' ? pkg.bin : pkg.bin && pkg.bin.dsh;
  if (!bin) throw new Error('dsh: в пакете нет bin');

  const binPath = path.join(root, bin);
  process.env.DSH_HOME = process.env.DSH_HOME || path.join(home, '.dsh');

  process.argv = [process.argv[0], binPath, 'web', '--no-open'];
  console.log('[attach] booting dsh:', binPath, 'home:', process.env.DSH_HOME);

  await import(pathToFileURL(binPath).href);
}

main().catch((err) => {
  console.error('[attach] dsh failed:', (err && (err.stack || err.message)) || err);
  process.exitCode = 1;
});
