// Упаковка движка в один файл для загрузки с телефона.
// Формат простой: заголовок + записи [путь][исходный размер][сжатый размер][байты].
// Сжатие — zlib (RFC 1950), его iOS умеет разжимать системным API без зависимостей.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const root = process.argv[2] || 'app/Engine';
const out = process.argv[3] || 'app/engine.bin';

const files = [];
function walk(dir, rel = '') {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    const relPath = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      walk(full, relPath);
    } else if (entry.isFile()) {
      files.push({ full, relPath });
    }
  }
}

walk(root);
files.sort((a, b) => a.relPath.localeCompare(b.relPath));

const header = Buffer.alloc(10);
header.write('ATGE', 0, 'ascii');
header.writeUInt16LE(1, 4);
header.writeUInt32LE(files.length, 6);

const chunks = [header];

for (const file of files) {
  const raw = fs.readFileSync(file.full);
  const compressed = zlib.deflateSync(raw, { level: 9 });
  const name = Buffer.from(file.relPath, 'utf8');

  const meta = Buffer.alloc(2 + name.length + 8);
  meta.writeUInt16LE(name.length, 0);
  name.copy(meta, 2);
  meta.writeUInt32LE(raw.length, 2 + name.length);
  meta.writeUInt32LE(compressed.length, 6 + name.length);

  chunks.push(meta, compressed);
}

fs.writeFileSync(out, Buffer.concat(chunks));
const size = fs.statSync(out).size;
console.log(`pack-engine: ${files.length} файлов, ${(size / 1_048_576).toFixed(1)} МБ → ${out}`);
