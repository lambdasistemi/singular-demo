// The kit release this repository builds: the pinned Singular release and the kit's revision, as in v0.14.0-1.
// The revision is kit/revision, the only place it is written by hand; the Singular release is read by version.js.
// A new revision is a kit that changes while Singular stays the same; a Singular bump (tools/bump.sh) starts again at 1.
// The step files write it as @RELEASE@ (the name of the kit's folder and of its release), and the builders put it in.
const fs = require('node:fs');
const path = require('node:path');

const version = require('./version.js');
const revision = fs
  .readFileSync(path.join(__dirname, '..', '..', 'kit', 'revision'), 'utf8')
  .trim();
if (!/^[1-9][0-9]*$/.test(revision))
  throw new Error('release.js: kit/revision is not a whole number from 1');
module.exports = `${version}-${revision}`;
