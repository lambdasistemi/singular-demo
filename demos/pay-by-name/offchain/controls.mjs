// TEST ONLY: the controls of the name sink. The scenario test runs them after the story; nothing of the story needs them.
//   node controls.cjs keys DIR NAME...            signing keys for the test roles: DIR/NAME.sk, .address, .skey
//   node controls.cjs controls RUN ACTIVE1 ACTIVE2 [ONLY]
//        the sink refuses what it must refuse, each with its label, and accepts what it must accept
//   node controls.cjs dead RUN ACTIVE STALE_OUTPUT
//        the name is over: no live token, and a move built on the old registry output is refused by the node
// The provider comes from ./singular.json (or $SINGULAR_CONFIG). A control that must be refused is built with a fixed
// execution budget when the local evaluator already refuses it, so that the node gives its own verdict on it too.
import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import {
  CML,
  Constr,
  credentialToAddress,
  Data,
  datumToHash,
  generatePrivateKey,
  makeAikenEvaluator,
  toPublicKey,
} from '@lucid-evolution/lucid';
import { addrKeyhash } from './addr.mjs';
import { makeLucid, rawUtxoInfo, readFileSync, textToHex, toUtxo, utxosWithUnit } from './lib.mjs';
import { loadVariantBlueprint, sinkScript } from './sink.mjs';
import { buildTx, lovelaceOf, registeredAddress, registryOutput } from './tx.mjs';

const aiken = makeAikenEvaluator();
const FIXED_BUDGET = { mem: 20_000_000, steps: 2_000_000_000 };
const TAGS = ['spend', 'mint', 'publish', 'withdraw', 'vote', 'propose'];
const clean = (e) =>
  String(e?.message ?? e)
    .replace(/\s+/g, ' ')
    .trim();

// ---- the keys of the test roles

function keys(dir, names) {
  mkdirSync(dir, { recursive: true });
  for (const name of names) {
    const sk = generatePrivateKey();
    writeFileSync(`${dir}/${name}.sk`, `${sk}\n`, { mode: 0o600 });
    const raw = Buffer.from(CML.PrivateKey.from_bech32(sk).to_raw_bytes()).toString('hex');
    // the cardano-cli signing key file, which Singular's --wallet-skey reads
    const skey = {
      type: 'PaymentSigningKeyShelley_ed25519',
      description: 'Payment Signing Key',
      cborHex: `5820${raw}`,
    };
    writeFileSync(`${dir}/${name}.skey`, `${JSON.stringify(skey)}\n`, { mode: 0o600 });
    const hash = CML.PublicKey.from_bech32(toPublicKey(sk)).hash().to_hex();
    const address = credentialToAddress('Custom', { type: 'Key', hash });
    writeFileSync(`${dir}/${name}.address`, `${address}\n`);
    console.log(`${name} ${address}`);
  }
}

// ---- building a transaction, and what the local evaluator and the node say about it

// the redeemers (tag, index) of a transaction, whatever the encoding of its redeemer set
function redeemerKeys(txHex) {
  const redeemers = CML.Transaction.from_cbor_hex(txHex).witness_set().redeemers();
  if (!redeemers) return [];
  const list = redeemers.as_arr_legacy_redeemer();
  if (list) {
    return Array.from({ length: list.len() }, (_, i) => list.get(i)).map((r) => ({
      tag: Number(r.tag()),
      index: Number(r.index()),
    }));
  }
  const map = redeemers.as_map_redeemer_key_to_redeemer_val().keys();
  return Array.from({ length: map.len() }, (_, i) => map.get(i)).map((k) => ({
    tag: Number(k.tag()),
    index: Number(k.index()),
  }));
}
const outRefsOf = (list) =>
  list
    ? Array.from({ length: list.len() }, (_, i) => list.get(i)).map((i) => ({
        txHash: i.transaction_id().to_hex(),
        outputIndex: Number(i.index()),
      }))
    : [];

// The node's answer is a few KB of ledger error plus the whole script and transaction: keep what identifies the failure.
function nodeSummary(raw) {
  const text = raw.replace(/\\+n/g, '\n').replace(/\\+"/g, '"');
  const rules =
    [
      'ValidationTagMismatch',
      'MissingRequiredDatums',
      'NotAllowedSupplementalDatums',
      'BadInputsUTxO',
      'ScriptsNotPaidUTxO',
    ]
      .filter((n) => text.includes(n))
      .join(' + ') || 'rejected';
  const hash = (text.match(/The script hash is:ScriptHash "([0-9a-f]{56})"/) ?? [])[1];
  const failure = (text.match(/The plutus evaluation error is: ([^\n]*)\n([^\n]*)\n([^\n]*)/) ?? [])
    .slice(1)
    .join(' ')
    .replace(/\s+/g, ' ');
  return hash
    ? `${rules}; Plutus failure in script ${hash}; ${failure}`
    : `${rules} (a ledger rule, before any script runs)`;
}

// the exact bytes the node refused, evaluated again here, to read the script's own label
async function reEvaluate(lucid, txHex) {
  const body = CML.Transaction.from_cbor_hex(txHex).body();
  const refs = [
    ...outRefsOf(body.inputs()),
    ...outRefsOf(body.reference_inputs()),
    ...outRefsOf(body.collateral_inputs()),
  ];
  const c = lucid.config();
  try {
    const additionalUTxOs = await lucid.utxosByOutRef(refs);
    await aiken.evaluate({
      tx: txHex,
      additionalUTxOs,
      context: {
        network: c.network,
        slotConfig: c.slotConfig,
        protocolParameters: c.protocolParameters,
        costModels: c.costModels,
      },
    });
    return 'evaluated fine locally';
  } catch (e) {
    return clean(e);
  }
}

async function lucidFor(skFile) {
  const lucid = await makeLucid();
  lucid.selectWallet.fromPrivateKey(readFileSync(skFile, 'utf8').trim());
  return lucid;
}

// plan: see buildTx. expect: 'accept' or 'reject'. A rejection is judged by the label of the script and by the node.
async function attempt({ label, lucid, plan, expect }) {
  let localError = null;
  const evaluator = {
    name: 'aiken-or-fixed',
    evaluate: async (args) => {
      try {
        return await aiken.evaluate(args);
      } catch (e) {
        localError = clean(e);
        if (expect.accept) throw e;
        return redeemerKeys(args.tx).map((k) => ({
          ex_units: { ...FIXED_BUDGET },
          redeemer_index: k.index,
          redeemer_tag: TAGS[k.tag],
        }));
      }
    },
  };
  const out = {
    label,
    expect,
    localError: null,
    nodeError: null,
    exactError: null,
    accepted: false,
    txHash: null,
  };
  let built;
  try {
    built = await buildTx(lucid, { ...plan, evaluator });
  } catch (e) {
    out.localError = localError ?? clean(e);
    return out;
  }
  out.localError = localError;
  const signed = await built.sign.withWallet().complete();
  try {
    out.txHash = await signed.submit();
    await lucid.awaitTx(out.txHash);
    out.accepted = true;
  } catch (e) {
    out.nodeError = nodeSummary(String(e?.message ?? e));
    out.exactError = await reEvaluate(lucid, signed.toCBOR());
  }
  return out;
}

const labelOf = (text) => (text ?? '').match(/Trace (sink-[a-z-]+)/)?.[1];

// judges one attempt against what was expected of it; prints a line a reader and the scenario test can both use
function judge(r) {
  const { expect } = r;
  let ok;
  if (expect.accept) ok = r.accepted;
  else if (expect.node)
    ok =
      !r.accepted &&
      expect.node.test(r.nodeError ?? '') &&
      (!expect.label ||
        (labelOf(r.localError) === expect.label && labelOf(r.exactError) === expect.label));
  else ok = false;
  console.log(
    `--- ${r.label}  [expected: ${expect.accept ? 'ACCEPTED' : `REJECTED${expect.label ? ` with ${expect.label}` : ''}`}]`,
  );
  if (r.accepted)
    console.log(
      `ACCEPTED by the node, tx ${r.txHash}${r.localError ? `  (the local evaluator had said: ${r.localError})` : ''}`,
    );
  else console.log('REJECTED');
  if (r.localError) console.log(`  local evaluator: ${r.localError}`);
  if (r.nodeError) console.log(`  node:            ${r.nodeError}`);
  if (r.exactError) console.log(`  same bytes, local evaluator: ${r.exactError}`);
  console.log(`CONTROL ${ok ? 'PASS' : 'FAIL'} ${r.label}`);
  return ok;
}

const SCRIPT_REFUSED = /ValidationTagMismatch/;
const show = (utxos) =>
  utxos
    .map(
      (u) =>
        `  ${u.txHash}#${u.outputIndex}  ${u.assets.lovelace} lovelace${u.datum ? ' inline datum' : ''}${u.datumHash ? ` datum hash ${u.datumHash.slice(0, 12)}..` : ''}`,
    )
    .join('\n') || '  (none)';
const pay = (address, lovelace) => ({ address, assets: { lovelace } });

// ---- the controls

async function controls(run, active1, active2, only) {
  const want = (id) => !only || only === id;
  const read = (file) => readFileSync(`${run}/${file}`, 'utf8').trim();
  const attackerAddr = read('keys/attacker.address');
  const sinkA = sinkScript({ activePolicy: active1, name: 'alice' });
  const stranger = await lucidFor(`${run}/keys/stranger.sk`);
  const attacker = await lucidFor(`${run}/keys/attacker.sk`);
  const aliceReg = await registryOutput(active1, 'alice');
  const registered = registeredAddress(aliceReg);
  const results = [];
  const send = async (lucid, tx) => {
    const h = await (await (await tx.complete()).sign.withWallet().complete()).submit();
    await lucid.awaitTx(h);
    return h;
  };
  const check = (r) => {
    results.push([r.label, judge(r)]);
    return r;
  };

  console.log(
    `active policy, registry 1: ${active1}\nactive policy, registry 2: ${active2} ${active1 === active2 ? '(SAME)' : '(DIFFERENT)'}`,
  );
  console.log(`sink of alice: ${sinkA.address}, script hash ${sinkA.hash}`);
  console.log(`registered address of alice now: ${registered}`);
  const sinkNow = await stranger.utxosAt(sinkA.address);
  console.log(`sink before the controls:\n${show(sinkNow)}`);

  // a move out of a sink: `amount` to `to`, the rest back to the sink (under `datum`, when given)
  const move = (
    label,
    expect,
    {
      to,
      ref = aliceReg,
      readFrom = [ref],
      amount = 4_000_000n,
      lucid = stranger,
      utxos = sinkNow,
      datum,
      redeemerRef = ref,
      sink = sinkA,
    } = {},
  ) =>
    attempt({
      label,
      lucid,
      expect,
      plan: {
        readFrom,
        redeemers: [{ utxos, ref: redeemerRef }],
        scripts: [sink.script],
        pays: [
          pay(to, amount),
          {
            address: sink.address,
            assets: { lovelace: lovelaceOf(utxos) - amount },
            ...(datum ? { datum } : {}),
          },
        ],
      },
    });

  if (want('attacker')) {
    check(
      await move(
        'attacker: 4 ada to the attacker, not to the registered address',
        { node: SCRIPT_REFUSED, label: 'sink-conservation' },
        { to: attackerAddr },
      ),
    );
  }

  if (want('forged')) {
    console.log(
      '\n[forged] the attacker makes an output at its own address with an inline datum for `alice` (the real control, the attacker as the payload) and NO token',
    );
    const real = Data.from(aliceReg.datum);
    const payload = new Constr(0, [new Constr(0, [addrKeyhash(attackerAddr)]), new Constr(1, [])]);
    const forgedDatum = Data.to(new Constr(0, [real.fields[0], payload]));
    const h = await send(
      attacker,
      attacker
        .newTx()
        .pay.ToAddressWithData(
          attackerAddr,
          { kind: 'inline', value: forgedDatum },
          { lovelace: 3_000_000n },
        ),
    );
    const forged = (await attacker.utxosAt(attackerAddr)).find((u) => u.txHash === h && u.datum);
    console.log(
      `forged output ${forged.txHash}#${forged.outputIndex} holds ${Object.keys(forged.assets).join(',')} only; the real registry output holds ${Object.keys(aliceReg.assets).join(', ')}`,
    );
    check(
      await move(
        'forged: the output without the token as the reference, 4 ada to the attacker',
        { node: SCRIPT_REFUSED, label: 'sink-token' },
        { to: attackerAddr, ref: forged, lucid: attacker },
      ),
    );
  }

  if (want('second')) {
    const second = await registryOutput(active2, 'alice');
    console.log(
      `\n[second] the attacker's own registry: its key alice, token policy ${active2}, registered address ${registeredAddress(second)}`,
    );
    check(
      await move(
        'second registry: its alice output as the reference, 4 ada to the attacker',
        { node: SCRIPT_REFUSED, label: 'sink-token' },
        { to: attackerAddr, ref: second },
      ),
    );
  }

  if (want('noref')) {
    check(
      await move(
        'no reference: the registry output left out, otherwise a valid move to the registered address',
        { node: SCRIPT_REFUSED, label: 'sink-no-reference' },
        { to: registered, readFrom: [] },
      ),
    );
  }

  if (want('datum')) {
    const publicDatum = Data.to(new Constr(0, []));
    const randomHash = randomBytes(32).toString('hex');
    check(
      await move(
        'datum hash, public: the rest back to the sink under the hash of a known datum',
        { node: SCRIPT_REFUSED, label: 'sink-datum-hash' },
        {
          to: registered,
          amount: 2_000_000n,
          datum: { kind: 'hash', value: datumToHash(publicDatum) },
        },
      ),
    );
    check(
      await move(
        'datum hash, random: the rest back to the sink under a hash nobody has a datum for',
        { node: SCRIPT_REFUSED, label: 'sink-datum-hash' },
        { to: registered, amount: 2_000_000n, datum: { kind: 'hash', value: randomHash } },
      ),
    );
    console.log(
      `the sink is unchanged after the two refusals:\n${show(await stranger.utxosAt(sinkA.address))}`,
    );
    check(
      await move(
        'inline datum: the rest back to the sink under an inline datum',
        { accept: true },
        { to: registered, amount: 2_000_000n, datum: { kind: 'inline', value: publicDatum } },
      ),
    );
    const inline = await stranger.utxosAt(sinkA.address);
    console.log(`the sink now:\n${show(inline)}`);
    check(
      await move(
        'inline datum, spent: a later move spends the output that carries it',
        { accept: true },
        { to: registered, amount: 1_000_000n, utxos: inline },
      ),
    );
  }

  if (want('two')) {
    console.log(
      '\n[two] alice-tips is registered at the same address as alice; one transaction spends both sinks, pays one amount to the registered address and the other to the attacker',
    );
    const sinkTips = sinkScript({ activePolicy: active1, name: 'alice-tips' });
    const tipsReg = await registryOutput(active1, 'alice-tips');
    console.log(
      `registered address of alice-tips: ${registeredAddress(tipsReg)} (the same as alice: ${registeredAddress(tipsReg) === registered})`,
    );
    console.log(
      `stranger -> sink of alice-tips, 12 ada, tx ${await send(stranger, stranger.newTx().pay.ToAddress(sinkTips.address, { lovelace: 12_000_000n }))}`,
    );
    const attack = (label, expect, A, B, a, b) =>
      attempt({
        label,
        lucid: stranger,
        expect,
        plan: {
          readFrom: [aliceReg, tipsReg],
          scripts: [a.script, b.script],
          redeemers: [
            { utxos: A, ref: aliceReg },
            { utxos: B, ref: tipsReg },
          ],
          pays: [pay(registered, lovelaceOf(A)), pay(attackerAddr, lovelaceOf(B))],
        },
      });
    const sa = await stranger.utxosAt(sinkA.address);
    const sb = await stranger.utxosAt(sinkTips.address);
    check(
      await attack(
        `two sinks: both in one transaction, ${lovelaceOf(sa)} to the registered address and ${lovelaceOf(sb)} to the attacker`,
        { node: SCRIPT_REFUSED, label: 'sink-foreign-script' },
        sa,
        sb,
        sinkA,
        sinkTips,
      ),
    );

    const variant = loadVariantBlueprint();
    const vA = sinkScript({ activePolicy: active1, name: 'alice' }, variant);
    const vB = sinkScript({ activePolicy: active1, name: 'alice-tips' }, variant);
    console.log(
      `the variant without check 6, script hashes ${vA.hash} ${vB.hash} (the real ones: ${sinkA.hash} ${sinkTips.hash})`,
    );
    console.log(
      `stranger -> the variant sinks, 13 ada and 12 ada, tx ${await send(stranger, stranger.newTx().pay.ToAddress(vA.address, { lovelace: 13_000_000n }).pay.ToAddress(vB.address, { lovelace: 12_000_000n }))}`,
    );
    const va = await stranger.utxosAt(vA.address);
    const vb = await stranger.utxosAt(vB.address);
    const before = lovelaceOf(await stranger.utxosAt(attackerAddr));
    check(
      await attack(
        'two sinks, the variant without check 6: the same attack, which must now succeed (the check is not vacuous)',
        { accept: true },
        va,
        vb,
        vA,
        vB,
      ),
    );
    console.log(
      `the attacker's address gained ${lovelaceOf(await stranger.utxosAt(attackerAddr)) - before} lovelace: the second sink's money, the registered address paid once`,
    );
  }

  console.log(
    `\n=== ${results.filter(([, ok]) => ok).length} of ${results.length} controls as expected`,
  );
  for (const [label, ok] of results) console.log(`${ok ? 'PASS' : 'FAIL'} ${label}`);
  return results.every(([, ok]) => ok);
}

// ---- the name is over

async function dead(run, active, staleRef) {
  const live = await utxosWithUnit(active + textToHex('alice'));
  console.log(`live outputs holding the token (active policy, "alice"): ${live.length}`);
  const sink = sinkScript({ activePolicy: active, name: 'alice' });
  const stranger = await lucidFor(`${run}/keys/stranger.sk`);
  const sinkUtxos = await stranger.utxosAt(sink.address);
  console.log(`the sink ${sink.address} still holds ${lovelaceOf(sinkUtxos)} lovelace`);
  const [txHash, ix] = staleRef.split('#');
  const [row] = await rawUtxoInfo([{ txHash, outputIndex: Number(ix) }]);
  console.log(`the last registry output of alice, ${staleRef}: is_spent = ${row.is_spent}`);
  const stale = toUtxo(row);
  const destination = registeredAddress(stale);
  const r = await attempt({
    label: `dead sink: a move built on the old registry output (spent, but still known to us), 1 ada to ${destination}`,
    lucid: stranger,
    expect: { node: /BadInputsUTxO/ },
    plan: {
      readFrom: [stale],
      redeemers: [{ utxos: sinkUtxos, ref: stale }],
      scripts: [sink.script],
      pays: [pay(destination, 1_000_000n), pay(sink.address, lovelaceOf(sinkUtxos) - 1_000_000n)],
    },
  });
  return judge(r) && live.length === 0;
}

// ---- the command

async function main() {
  const [command, ...args] = process.argv.slice(2);
  switch (command) {
    case 'keys':
      keys(args[0], args.slice(1));
      return true;
    case 'controls':
      return controls(args[0], args[1], args[2], args[3]);
    case 'dead':
      return dead(args[0], args[1], args[2]);
    default:
      console.error(
        'usage: controls.cjs keys DIR NAME... | controls RUN ACTIVE1 ACTIVE2 [ONLY] | dead RUN ACTIVE STALE_OUTPUT',
      );
      return false;
  }
}
main().then(
  (ok) => process.exit(ok ? 0 : 1),
  (e) => {
    console.error(`error: ${e.stack ?? e}`);
    process.exit(1);
  },
);
