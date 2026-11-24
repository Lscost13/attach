// Скрипт запуска ядра. Лежит в самом приложении, а не в скачанном движке:
// так его можно править обновлением сборки, не скачивая 269 МБ заново.
// Сам DSH и node_modules — в ATTACH_ENGINE (Documents/engine).
//
// DSH слушает 127.0.0.1 и печатает адрес с токеном — перехватываем его
// и кладём в engine.json, чтобы SwiftUI знал, куда стучаться.
// Всё, что движок пишет в консоль, дублируем в engine.log: на телефоне
// другого способа увидеть, что случилось, нет.

const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const engineDir = process.env.ATTACH_ENGINE || __dirname;
const home = process.env.HOME || engineDir;
const workdir = process.env.ATTACH_WORKDIR || home;
const stateDir = path.join(home, '.attach');
const stateFile = path.join(stateDir, 'engine.json');
const logFile = path.join(stateDir, 'engine.log');
const logLimit = 512 * 1024;

fs.mkdirSync(stateDir, { recursive: true });
try {
  fs.mkdirSync(workdir, { recursive: true });
} catch {}

try {
  if (fs.statSync(logFile).size > logLimit) fs.truncateSync(logFile, 0);
} catch {}

function toLog(text) {
  try {
    fs.appendFileSync(logFile, text);
  } catch {}
}

function describe(chunk) {
  if (typeof chunk === 'string') return chunk;
  if (Buffer.isBuffer(chunk)) return chunk.toString('utf8');
  try {
    return String(chunk);
  } catch {
    return '';
  }
}

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
  toLog(`[attach] engine published: ${url}\n`);
}

// --- перехватываем вывод -------------------------------------------------

let seen = false;

function watch(text) {
  if (seen) return;
  const match = text.match(/dsh web:\s*(https?:\/\/\S+)/);
  if (match) {
    seen = true;
    try {
      publish(match[1]);
    } catch (error) {
      toLog(`[attach] publish failed: ${error && error.message}\n`);
    }
  }
}

const stdoutWrite = process.stdout.write.bind(process.stdout);
process.stdout.write = function (chunk, ...rest) {
  try {
    const text = describe(chunk);
    toLog(text);
    watch(text);
  } catch {}
  return stdoutWrite(chunk, ...rest);
};

const stderrWrite = process.stderr.write.bind(process.stderr);
process.stderr.write = function (chunk, ...rest) {
  try {
    const text = describe(chunk);
    toLog(text);
    watch(text);
  } catch {}
  return stderrWrite(chunk, ...rest);
};

// --- не даём движку уронить приложение молча ----------------------------

process.on('uncaughtException', (error) => {
  toLog(`[attach] uncaught: ${(error && (error.stack || error.message)) || error}\n`);
});

process.on('unhandledRejection', (reason) => {
  toLog(`[attach] unhandled rejection: ${(reason && (reason.stack || reason.message)) || reason}\n`);
});

process.on('exit', (code) => {
  toLog(`[attach] process exit ${code}\n`);
});

process.exit = function (code) {
  toLog(`[attach] process.exit(${code}) перехвачен\n`);
  throw new Error(`process.exit(${code})`);
};

// --- сам движок ---------------------------------------------------------

async function main() {
  toLog(`\n[attach] node ${process.version}, pid ${process.pid}\n`);
  toLog(`[attach] engine ${engineDir}\n`);
  toLog(`[attach] workdir ${workdir}\n`);

  try {
    process.chdir(workdir);
  } catch (error) {
    toLog(`[attach] chdir failed: ${error && error.message}\n`);
  }

  const pkgPath = require.resolve('@deepseek-ai/dsh/package.json', { paths: [engineDir] });
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
    String(process.env.ATTACH_PORT || 3080),
  ];

  toLog(`[attach] dsh ${pkg.version}: ${binPath}\n`);
  const mod = await import(pathToFileURL(binPath).href);
  await mod.runCli();
}

main().catch((error) => {
  const text = (error && (error.stack || error.message)) || String(error);
  toLog(`[attach] dsh failed: ${text}\n`);
  process.exitCode = 1;
});
