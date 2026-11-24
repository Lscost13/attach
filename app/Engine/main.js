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
const zlib = require('zlib');
const { pathToFileURL } = require('url');

const engineDir = process.env.ATTACH_ENGINE || __dirname;
const home = process.env.HOME || engineDir;
const workdir = process.env.ATTACH_WORKDIR || home;
const stateDir = path.join(home, '.attach');
const stateFile = path.join(stateDir, 'engine.json');
const logFile = path.join(stateDir, 'engine.log');
const archiveFile = path.join(stateDir, 'engine.bin');
const markerFile = path.join(stateDir, 'engine-ready');
const unpackFile = path.join(stateDir, 'unpack.json');
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

// --- распаковка движка ---------------------------------------------------
// Раньше это делал Swift системным zlib, и часть файлов приезжала битой:
// DSH падал на «Invalid or unexpected token». Node разжимает ровно тем же
// zlib, которым архив собран, поэтому распаковываем здесь.

function writeUnpack(data) {
  try {
    fs.writeFileSync(unpackFile, JSON.stringify(data));
  } catch {}
}

function readExact(fd, length, position) {
  const buffer = Buffer.alloc(length);
  let read = 0;
  while (read < length) {
    const chunk = fs.readSync(fd, buffer, read, length - read, position + read);
    if (chunk <= 0) throw new Error('архив обрезан');
    read += chunk;
  }
  return buffer;
}

function ensureEngine() {
  if (fs.existsSync(markerFile)) return;
  if (!fs.existsSync(archiveFile)) throw new Error(`нет файла движка: ${archiveFile}`);

  const size = fs.statSync(archiveFile).size;
  toLog(`[attach] unpack ${archiveFile} (${size} байт)\n`);
  writeUnpack({ phase: 'unpack', done: 0, total: 0 });

  const fd = fs.openSync(archiveFile, 'r');
  try {
    const header = readExact(fd, 10, 0);
    if (header.toString('ascii', 0, 4) !== 'ATGE') throw new Error('это не архив движка');

    const total = header.readUInt32LE(6);
    let offset = 10;

    for (let index = 0; index < total; index += 1) {
      const nameLength = readExact(fd, 2, offset).readUInt16LE(0);
      offset += 2;

      const name = readExact(fd, nameLength, offset).toString('utf8');
      offset += nameLength;

      const sizes = readExact(fd, 8, offset);
      offset += 8;
      const rawLength = sizes.readUInt32LE(0);
      const compLength = sizes.readUInt32LE(4);

      let data = Buffer.alloc(0);
      if (compLength > 0) {
        const compressed = readExact(fd, compLength, offset);
        if (rawLength > 0) {
          try {
            data = zlib.inflateSync(compressed);
          } catch {
            data = zlib.inflateRawSync(compressed.subarray(2));
          }
          if (data.length !== rawLength) {
            throw new Error(`${name}: ${data.length} байт вместо ${rawLength}`);
          }
        }
      }
      offset += compLength;

      const target = path.join(engineDir, name);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, data);

      if ((index + 1) % 500 === 0) {
        writeUnpack({ phase: 'unpack', done: index + 1, total });
      }
    }

    fs.writeFileSync(markerFile, String(size));
    writeUnpack({ phase: 'done', done: total, total });
    try {
      fs.unlinkSync(archiveFile);
    } catch {}
    toLog(`[attach] unpack ok: ${total} файлов\n`);
  } catch (error) {
    writeUnpack({ phase: 'failed', error: String((error && error.message) || error) });
    toLog(`[attach] unpack failed: ${(error && (error.stack || error.message)) || error}\n`);
    throw error;
  } finally {
    try {
      fs.closeSync(fd);
    } catch {}
  }
}

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

  ensureEngine();

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
