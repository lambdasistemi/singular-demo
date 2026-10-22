// The sink script from the compiled blueprint of the validator (no Aiken needed here).
// Two parameters close it over a name: the registry's active policy and the name.
import { readFileSync } from 'node:fs';
import {
  applyParamsToScript,
  validatorToAddress,
  validatorToScriptHash,
} from '@lucid-evolution/lucid';
import { embeddedSinkBlueprint, embeddedVariantBlueprint } from './embedded.mjs';
import { textToHex } from './lib.mjs';

const NO_BLUEPRINT =
  'no compiled sink validator: name its plutus.json in $SINK_BLUEPRINT (nix build .#pay-by-name-sink makes it)';

// The blueprint of the sink validator: the file named, or $SINK_BLUEPRINT, or the one inside the bundle.
export const loadSinkBlueprint = (path) => {
  const file = path ?? process.env.SINK_BLUEPRINT;
  if (file) return JSON.parse(readFileSync(file, 'utf8'));
  if (embeddedSinkBlueprint) return JSON.parse(embeddedSinkBlueprint);
  throw new Error(NO_BLUEPRINT);
};

// The variant without check 6, for the tests that show the check is not vacuous.
export const loadVariantBlueprint = () => {
  if (process.env.SINK_VARIANT_BLUEPRINT)
    return JSON.parse(readFileSync(process.env.SINK_VARIANT_BLUEPRINT, 'utf8'));
  if (embeddedVariantBlueprint) return JSON.parse(embeddedVariantBlueprint);
  throw new Error(
    'no variant of the sink validator: name its plutus.json in $SINK_VARIANT_BLUEPRINT',
  );
};

// a blueprint given as an object, or as a path, or not at all (then the default one)
const blueprintOf = (b) => (b && typeof b === 'object' ? b : loadSinkBlueprint(b));
const compiledCode = (b) =>
  blueprintOf(b).validators.find((v) => v.title === 'sink.sink.spend').compiledCode;

// The registry's sink script: the validator applied to the registry's active policy only (the first parameter).
// Applying a name to it later gives the same script as applying both at once.
export const registrySinkScript = (activePolicy, blueprint) =>
  applyParamsToScript(compiledCode(blueprint), [activePolicy]);

// registrySink: a registry sink script (hex) to apply the name to, instead of the blueprint (the published one)
export const sinkScript = ({ activePolicy, name, registrySink }, blueprint) => {
  const applied = registrySink
    ? applyParamsToScript(registrySink, [textToHex(name)])
    : applyParamsToScript(compiledCode(blueprint), [activePolicy, textToHex(name)]);
  const script = { type: 'PlutusV3', script: applied };
  return {
    script,
    hash: validatorToScriptHash(script),
    address: validatorToAddress('Custom', script),
    activePolicy,
    name,
  };
};

// a registry sink script given as a file: the published JSON ("sink-script"), or the bare hex
export const readRegistrySink = (file) => {
  const text = readFileSync(file, 'utf8').trim();
  try {
    const published = JSON.parse(text);
    if (published['sink-script']) return published['sink-script'];
  } catch {
    // not JSON: the bare hex
  }
  return text;
};
