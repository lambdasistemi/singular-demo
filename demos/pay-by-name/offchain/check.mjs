// check-registry: is this registry's pinned application the release's open-datum validator applied to this state token,
// and is the sink script a registry's creator published the sink validator applied to this registry's active policy?
import { applyParamsToScript, validatorToScriptHash } from '@lucid-evolution/lucid';
import { Data, config, utxosWithUnit, provider, readFileSync } from './lib.mjs';
import { addrJson, registryToken } from './addr.mjs';
import { registrySinkScript } from './sink.mjs';

// args: { describe?: path, published?: path, stateToken?, stateOutput?: "txid#ix" }   exit code 1 on any mismatch
// The registry is named by a describe file, by --state-token, or by the "registry" (its address) of the settings file.
export async function checkRegistry(args) {
  const cfg = config();
  const describe = args.describe ? JSON.parse(readFileSync(args.describe, 'utf8')) : undefined;
  const token =
    args.stateToken ??
    describe?.registry?.stateToken ??
    (cfg.registry ? registryToken(cfg.registry) : undefined);
  if (!token)
    throw new Error(
      'no registry: pass --state-token, a describe file, or put "registry" (its address) in the settings file',
    );
  const [policy, name] = token.split('.');
  const blueprint = JSON.parse(
    readFileSync(args.blueprint ?? cfg.blueprint ?? process.env.blueprint, 'utf8'),
  );
  let bad = false;
  const say = (line) => console.log(line);

  // 1. the state output: found by the token on chain (or named by --state-output)
  let out;
  if (args.stateOutput) {
    const [txHash, ix] = args.stateOutput.split('#');
    out = (await provider.getUtxosByOutRef([{ txHash, outputIndex: Number(ix) }]))[0];
  } else {
    const live = await utxosWithUnit(policy + name);
    if (live.length !== 1) throw new Error(`the token has ${live.length} live outputs, expected 1`);
    out = live[0];
  }
  if (!out?.datum) throw new Error('the state output is not found or carries no inline datum');
  if (describe?.registry?.address) say(`registry:               ${describe.registry.address}`);
  say(`state token:            ${token}`);
  say(
    `state output:           ${out.txHash}#${out.outputIndex}${args.stateOutput ? ' (named on the command line)' : ' (found on chain by the token)'}`,
  );
  if (describe) {
    const same = describe.registry.stateOutput === `${out.txHash}#${out.outputIndex}`;
    say(
      `describe says:          ${describe.registry.stateOutput} (${same ? 'the same output' : 'a DIFFERENT output'})`,
    );
    if (!same) bad = true;
  }
  const holds = (out.assets[policy + name] ?? 0n) === 1n;
  say(`output holds the token: ${holds ? 'yes' : 'NO'}`);
  if (!holds) bad = true;

  // 2. at the release's state script?
  const stateHash = blueprint.validators.find((v) => v.title === 'state.state.spend').hash;
  const payment = addrJson(out.address).fields[0]; // Constr 1 = script credential
  const atState = payment.constructor === 1 && payment.fields[0].bytes === stateHash;
  say(`output at the release's state script ${stateHash}: ${atState ? 'yes' : 'NO'}`);
  if (!atState) bad = true;

  // 3. the state datum: StateDatum(State { root, tip, process_time, retract_time, application_policy, active_policy, absent_policy, terminal_policy })
  const datum = Data.from(out.datum);
  const state = datum.fields[0].fields;
  const [pinnedApp, pinnedActive] = [state[4], state[5]];

  // 4. the release's open-datum validator applied to this token (the parameter is statePolicy || stateName)
  const v = blueprint.validators.find((x) => x.title === 'open_datum.open_datum.spend');
  const derived = validatorToScriptHash({
    type: 'PlutusV3',
    script: applyParamsToScript(v.compiledCode, [policy + name]),
  });
  say(`pinned application policy (state datum):                 ${pinnedApp}`);
  say(`open_datum of the release applied to this state token:   ${derived}`);
  if (pinnedApp === derived) say('application: matches');
  else {
    say('application: does not match');
    bad = true;
  }

  // 5. the active policy: the registry's programs derive it from the release; here it is read for the sink script below
  say(`active policy (state datum):                              ${pinnedActive}`);

  // 6. the registry's sink script published by the registry's creator: is it the sink validator applied to this active policy?
  if (args.published) {
    const pub = JSON.parse(readFileSync(args.published, 'utf8'));
    let pubToken;
    try {
      pubToken = registryToken(pub.registry);
    } catch {}
    if (pubToken === token) say('published registry: matches');
    else {
      say(`published registry: does not match (${pub.registry} is not the registry checked)`);
      bad = true;
    }
    const mine = registrySinkScript(pinnedActive, args.sinkBlueprint);
    const same = pub['sink-script'] === mine;
    say(
      `published registry sink script: ${pub['sink-script'].length / 2} bytes; my recomputation (sink validator applied to the active policy above): ${mine.length / 2} bytes`,
    );
    say(
      same
        ? 'published registry sink script: matches'
        : 'published registry sink script: does not match',
    );
    if (!same) bad = true;
  }
  if (bad) process.exitCode = 1;
  return !bad;
}
