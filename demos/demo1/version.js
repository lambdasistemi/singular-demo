// The Singular release this repository is pinned to, read from flake.nix: the only place it is written by hand.
// The step files write it as @VERSION@, and the builders put it in.
const fs = require('fs');
const path = require('path');

const flake = fs.readFileSync(path.join(__dirname, '..', '..', 'flake.nix'), 'utf8');
const m = flake.match(/github:lambdasistemi\/singular\/(v\d+\.\d+\.\d+)"/);
if (!m) throw new Error('version.js: no Singular tag found in flake.nix');
module.exports = m[1];
