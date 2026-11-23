// Патчи движка под iOS: нативных аддонов там нет, поэтому два места
// подменяем чистыми JS-версиями. Источник идеи — Fish Pocket (MIT).
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2] || process.cwd();
const modules = path.join(root, 'node_modules');

function writeIfExists(pkgPath, file, content) {
  const dir = path.join(modules, pkgPath);
  if (!fs.existsSync(dir)) {
    console.log('patch-engine: нет пакета', pkgPath, '— пропускаю');
    return;
  }
  const target = path.join(dir, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content);
  console.log('patch-engine: подменён', path.relative(root, target));
}

// 1. node-addon-require-builtin: internal-модули отдаёт сам Node
//    при запуске с --expose-internals.
writeIfExists(
  'node-addon-require-builtin',
  'lib/index.js',
  `'use strict';
// Attach: iOS-версия аддона. Нативных биндингов на устройстве нет,
// internal-модули отдаёт сам Node, если запущен с --expose-internals.
if (!process.execArgv.includes('--expose-internals')) {
  throw new Error('node-addon-require-builtin: нужен запуск с --expose-internals');
}

function requireBuiltin(id) {
  return require(id);
}

function isAllowedInternalId() {
  return true;
}

function getBindingInfo() {
  return { mode: 'napi', product: 'require-builtin', backend: 'napi', abi: 'napi-v9' };
}

module.exports = {
  requireBuiltin,
  isAllowedInternalId,
  getBindingInfo,
  default: { requireBuiltin, isAllowedInternalId, getBindingInfo },
};
`
);

// 2. flock: в контейнер приложения второй процесс не попадёт, блокировка не нужна.
writeIfExists(
  '@deepseek-ai/node-addon-system',
  'lib/flock.js',
  `// Attach: iOS-заглушка flock. Нативного биндинга нет, а второй процесс
// в контейнер приложения всё равно не попадёт — блокировать некого.
export async function tryLockExclusive(fd) {
  if (!Number.isInteger(fd) || fd < 0) {
    throw Object.assign(new TypeError('invalid descriptor: ' + fd), {
      code: 'EBADF',
      syscall: 'flock',
    });
  }
}
`
);
