// npm раскладывает часть пакетов DSH вложенными node_modules, и некоторые
// копии приезжают битыми: без package.json и без index.js. Node тогда находит
// пустой каталог и падает на резолве. Вычищаем всё, где нет package.json.
import fs from 'node:fs';
import path from 'node:path';

const root = 'node_modules';
let removed = 0;

function walk(dir) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const full = path.join(dir, entry.name);

    if (entry.name === 'node_modules') {
      walk(full);
      continue;
    }
    if (entry.name.startsWith('@')) {
      walk(full);
      continue;
    }
    if (!fs.existsSync(path.join(full, 'package.json'))) {
      fs.rmSync(full, { recursive: true, force: true });
      removed += 1;
      continue;
    }
    walk(path.join(full, 'node_modules'));
  }
}

walk(root);
console.log(`clean-engine: removed ${removed} broken package dirs`);
