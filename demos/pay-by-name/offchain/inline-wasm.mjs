// Prepares the three WebAssembly packages for bundling into ONE file. Their node builds read the .wasm file from disk
// beside the script; this writes, into DIR, a copy of each entry in which that read is replaced by the bytes themselves
// (base64), so that nothing is read from disk when the bundle runs. The bundler then takes these copies instead of the packages.
//   node inline-wasm.mjs NODE_MODULES DIR
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const [modules, out] = process.argv.slice(2);
if (!modules || !out) {
  console.error('usage: node inline-wasm.mjs NODE_MODULES DIR');
  process.exit(2);
}

// each package: where its entry is, the text of the read to replace, the .wasm file beside it, the name of the copy
const PACKAGES = [
  [
    '@lucid-evolution/cml/dist/node/cardano_multiplatform_lib.js',
    "require('fs').readFileSync(wasmPath)",
    'cardano_multiplatform_lib_bg.wasm',
    'cml.cjs',
  ],
  [
    '@lucid-evolution/uplc/dist/speed/node/uplc_tx.js',
    "require('fs').readFileSync(path)",
    'uplc_tx_bg.wasm',
    'uplc.cjs',
  ],
  [
    '@emurgo/cardano-message-signing-nodejs/cardano_message_signing.js',
    "require('fs').readFileSync(path)",
    'cardano_message_signing_bg.wasm',
    'message-signing.cjs',
  ],
];

mkdirSync(out, { recursive: true });
for (const [entry, read, wasm, copy] of PACKAGES) {
  const file = join(modules, entry);
  const text = readFileSync(file, 'utf8');
  // a replacement must find its text, so a new version of a package cannot slip past unnoticed
  if (!text.includes(read)) {
    console.error(`inline-wasm.mjs: ${entry} no longer contains ${read}`);
    process.exit(1);
  }
  const bytes = readFileSync(join(dirname(file), wasm)).toString('base64');
  writeFileSync(
    join(out, copy),
    text.replace(read, `Buffer.from(${JSON.stringify(bytes)}, 'base64')`),
  );
  console.log(`${copy}: ${wasm} inlined, ${bytes.length} base64 characters`);
}
