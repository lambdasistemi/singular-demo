// The tools of the pay-by-name scenario, in one command:  sink-tools COMMAND [options]
// The provider and the network come from ./singular.json (or $SINGULAR_CONFIG), the file every person of the scenario has.
import { addrJson, addrKeyhash } from './addr.mjs';

const USAGE = `usage: sink-tools COMMAND [options]

  addr-json ADDRESS         the address as an Aiken Address, in Plutus data JSON (the payload of a key)
  addr-keyhash ADDRESS      the payment key hash of an address (the controller of a key booked from it)
  registry-sink --active-policy HEX
                            the sink validator applied to the registry's active policy only (the first parameter), in hex
  sink-address (--active-policy HEX | --registry-sink-script FILE) --name NAME
                            the sink of a name: its script hash and address
  check-registry [DESCRIBE.json] [--published REGISTRY.json] [--state-token TOKEN] [--state-output TXID#IX]
                            is the registry the release's? exits 1 when something does not match
  pay --from ADDRESS --out ADDRESS:LOVELACE [--out ...] --bundle FILE
                            an unsigned transaction paying the outputs, for 'singular wallet sign'
  move --active-policy HEX --name NAME --from ADDRESS (--lovelace N | --all) [--to ADDRESS] --bundle FILE
                            an unsigned transaction moving money out of the sink of a name to the address registered
                            under it; --to names another address, which the sink refuses
  (pay and move also take --sk FILE in place of --from and --bundle: they sign with that key and submit)
`;

const parse = (argv) => {
  const o = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--all') {
      o.all = true;
    } else if (a.startsWith('--')) {
      const key = a.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
      const value = argv[++i];
      if (value === undefined) throw new Error(`${a} needs a value`);
      o[key] = o[key] === undefined ? value : [].concat(o[key], value);
    } else {
      o._.push(a);
    }
  }
  return o;
};

const need = (o, ...keys) => {
  for (const k of keys) {
    if (o[k] === undefined)
      throw new Error(`missing --${k.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`);
  }
};

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const o = parse(rest);
  switch (command) {
    case undefined:
    case 'help':
    case '--help':
    case '-h':
      console.log(USAGE);
      break;
    case 'addr-json':
      console.log(JSON.stringify(addrJson(o._[0])));
      break;
    case 'addr-keyhash':
      console.log(addrKeyhash(o._[0]));
      break;
    case 'registry-sink': {
      need(o, 'activePolicy');
      const { registrySinkScript } = await import('./sink.mjs');
      console.log(registrySinkScript(o.activePolicy, o.sinkBlueprint));
      break;
    }
    case 'sink-address': {
      need(o, 'name');
      if (!o.activePolicy && !o.registrySinkScript)
        throw new Error('missing --active-policy or --registry-sink-script');
      const { sinkScript, readRegistrySink } = await import('./sink.mjs');
      const registrySink = o.registrySinkScript
        ? readRegistrySink(o.registrySinkScript)
        : undefined;
      const s = sinkScript(
        { activePolicy: o.activePolicy, name: o.name, registrySink },
        o.sinkBlueprint,
      );
      console.log(
        JSON.stringify({ scriptHash: s.hash, address: s.address, name: s.name }, null, 2),
      );
      break;
    }
    case 'check-registry': {
      const { checkRegistry } = await import('./check.mjs');
      await checkRegistry({
        describe: o._[0],
        published: o.published,
        stateToken: o.stateToken,
        stateOutput: o.stateOutput,
        blueprint: o.blueprint,
        sinkBlueprint: o.sinkBlueprint,
      });
      break;
    }
    case 'pay': {
      need(o, 'out');
      if (!o.from && !o.sk) throw new Error('missing --from or --sk');
      const { pay } = await import('./tx.mjs');
      await pay({ from: o.from, sk: o.sk, outs: [].concat(o.out), bundle: o.bundle });
      break;
    }
    case 'move': {
      need(o, 'activePolicy', 'name');
      if (!o.from && !o.sk) throw new Error('missing --from or --sk');
      if (!o.all && o.lovelace === undefined) throw new Error('missing --lovelace (or --all)');
      const { move } = await import('./tx.mjs');
      await move({
        activePolicy: o.activePolicy,
        name: o.name,
        from: o.from,
        sk: o.sk,
        lovelace: o.lovelace,
        all: o.all,
        bundle: o.bundle,
        sinkBlueprint: o.sinkBlueprint,
        to: o.to,
      });
      break;
    }
    default:
      console.error(`unknown command ${command}\n\n${USAGE}`);
      process.exitCode = 2;
  }
}

main().catch((e) => {
  console.error(`error: ${e.message ?? e}`);
  process.exit(1);
});
