// Замена нативного аддона node-addon-require-builtin на чистый JS.
// На iOS .node-бинарников нет, а DSH через этот аддон достаёт internal-модули.
// Решение то же, что у Fish Pocket: Node стартует с --expose-internals,
// и обычный require уже умеет internal/*.
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2] || process.cwd();
const pkgDir = path.join(root, 'node_modules', 'node-addon-require-builtin');
const target = path.join(pkgDir, 'lib', 'index.js');

if (!fs.existsSync(pkgDir)) {
  console.error('patch-engine: node-addon-require-builtin не найден в', pkgDir);
  process.exit(1);
}

const shim = `'use strict';
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
`;

fs.writeFileSync(target, shim);
console.log('patch-engine: подменён', path.relative(root, target));
