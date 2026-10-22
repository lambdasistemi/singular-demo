// Building the two transactions of the scenario, pay and move, and handing them over:
//   --bundle FILE  an unsigned transaction in the bundle format of Singular, to be signed with `singular wallet sign --vault`
//   --sk FILE      sign with a JS key and submit (the test roles stranger and attacker)
import {
  Data,
  Constr,
  CML,
  makeLucid,
  tip,
  config,
  utxosWithUnit,
  dataToAddress,
  writeFileSync,
  readFileSync,
} from './lib.mjs';
import { sinkScript } from './sink.mjs';
import { registryToken } from './addr.mjs';
import { textToHex } from './lib.mjs';

export const redeemerFor = (ref) => Data.to(new Constr(0, [ref.txHash, BigInt(ref.outputIndex)]));
export const lovelaceOf = (utxos) => utxos.reduce((s, u) => s + u.assets.lovelace, 0n);

// plan: { redeemers: [{utxos, ref}], readFrom: [utxo], pays: [{address, assets, datum?}], scripts: [script], evaluator? }
export async function buildTx(lucid, plan) {
  const t = await tip();
  let tx = lucid.newTx().validTo(t.block_time * 1000 + 600_000);
  if (plan.readFrom?.length) tx = tx.readFrom(plan.readFrom);
  for (const g of plan.redeemers ?? []) tx = tx.collectFrom(g.utxos, redeemerFor(g.ref));
  for (const p of plan.pays)
    tx = p.datum
      ? tx.pay.ToAddressWithData(p.address, p.datum, p.assets)
      : tx.pay.ToAddress(p.address, p.assets);
  for (const s of plan.scripts ?? []) tx = tx.attach.SpendingValidator(s);
  return tx.complete(plan.evaluator ? { evaluator: plan.evaluator } : {});
}

// the wallet that pays the fee: an address (its vault signs later) or a JS key
export async function selectWallet(lucid, { from, sk }) {
  if (sk) {
    lucid.selectWallet.fromPrivateKey(readFileSync(sk, 'utf8').trim());
    return lucid.wallet().address();
  }
  lucid.selectWallet.fromAddress(from, await lucid.utxosAt(from));
  return from;
}

export async function hand({ lucid, built, from, command, effects, bundle }) {
  if (bundle) {
    const cbor = built.toCBOR();
    const ttl = CML.Transaction.from_cbor_hex(cbor).body().ttl();
    const file = {
      command,
      networkMagic: config()['network-magic'],
      signers: [from],
      stateToken: config().registry ? registryToken(config().registry) : undefined,
      transactions: [
        {
          deadline: Number(ttl),
          effects,
          envelope: {
            cborHex: cbor,
            description: 'Ledger Cddl Format',
            type: 'Unwitnessed Tx ConwayEra',
          },
          identity: built.toHash(),
        },
      ],
      version: 1,
    };
    writeFileSync(bundle, `${JSON.stringify(file, null, 2)}\n`);
    console.log(`unsigned transaction ${file.transactions[0].identity} written to ${bundle}`);
    console.log(
      `next: singular wallet sign --vault <your vault> --out witnesses ${bundle} && singular submit --witnesses witnesses ${bundle}`,
    );
    return file.transactions[0].identity;
  }
  const signed = await built.sign.withWallet().complete();
  const h = await signed.submit();
  await lucid.awaitTx(h);
  console.log(`transaction ${h} submitted and confirmed`);
  return h;
}

export async function pay({ from, sk, outs, bundle }) {
  const lucid = await makeLucid();
  const payer = await selectWallet(lucid, { from, sk });
  const pays = outs.map((o) => {
    const [address, n] = o.split(':');
    return { address, assets: { lovelace: BigInt(n) } };
  });
  const built = await buildTx(lucid, { pays });
  return hand({
    lucid,
    built,
    from: payer,
    command: 'pay',
    effects: pays.map((p) => `pays ${p.assets.lovelace} lovelace to ${p.address}`),
    bundle,
  });
}

// The live registry output of a name: the one output holding the token (active policy, name)
export async function registryOutput(activePolicy, name) {
  const live = await utxosWithUnit(activePolicy + textToHex(name));
  if (live.length !== 1)
    throw new Error(
      `no live registry output holds the key ${JSON.stringify(name)} under ${activePolicy} (${live.length} found): the name is not registered, or is over`,
    );
  return live[0];
}
export const registeredAddress = (registryUtxo) =>
  dataToAddress(Data.from(registryUtxo.datum).fields[1]);

export async function move({
  activePolicy,
  name,
  from,
  sk,
  lovelace,
  all,
  bundle,
  sinkBlueprint,
  to,
}) {
  const sink = sinkScript({ activePolicy, name }, sinkBlueprint);
  const lucid = await makeLucid();
  const mover = await selectWallet(lucid, { from, sk });
  const registry = await registryOutput(activePolicy, name);
  const registered = registeredAddress(registry);
  const destination = to ?? registered; // --to: a destination of your own choosing, which the sink will refuse
  const sinkUtxos = await lucid.utxosAt(sink.address);
  if (sinkUtxos.length === 0) throw new Error(`the sink ${sink.address} holds nothing`);
  const total = lovelaceOf(sinkUtxos);
  const amount = all ? total : BigInt(lovelace);
  console.log(
    `name ${JSON.stringify(name)} is registered at ${registry.txHash}#${registry.outputIndex}; its address now: ${registered}`,
  );
  if (to) console.log(`moving to ${to} instead`);
  console.log(`sink ${sink.address} holds ${total} lovelace in ${sinkUtxos.length} output(s)`);
  const pays = [{ address: destination, assets: { lovelace: amount } }];
  if (total > amount) pays.push({ address: sink.address, assets: { lovelace: total - amount } });
  let built;
  try {
    built = await buildTx(lucid, {
      readFrom: [registry],
      redeemers: [{ utxos: sinkUtxos, ref: registry }],
      pays,
      scripts: [sink.script],
    });
  } catch (e) {
    console.error(
      `the sink refuses this move: ${String(e?.message ?? e)
        .replace(/\s+/g, ' ')
        .replace(/^"|"$/g, '')}`,
    );
    process.exit(1);
  }
  return hand({
    lucid,
    built,
    from: mover,
    command: 'move',
    effects: [
      `moves ${amount} lovelace from the sink to the address registered under ${name} (${destination})`,
      ...(total > amount ? [`${total - amount} lovelace stay in the sink`] : []),
    ],
    bundle,
  });
}
