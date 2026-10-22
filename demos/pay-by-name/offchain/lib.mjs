// Shared by the scenario tools: the provider (the Koios-style API of the devnet), a Lucid Evolution instance, small helpers.
// The provider URL and the network come from singular.json (or $SINGULAR_CONFIG), the file every actor already has.
import {
  Lucid,
  PROTOCOL_PARAMETERS_DEFAULT,
  CML,
  Data,
  Constr,
  credentialToAddress,
} from '@lucid-evolution/lucid';
import { webcrypto } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

// Node 18 has no global crypto, which the WebAssembly libraries draw their random numbers from
if (!globalThis.crypto) globalThis.crypto = webcrypto;

export const config = () =>
  JSON.parse(readFileSync(process.env.SINGULAR_CONFIG ?? 'singular.json', 'utf8'));
const base = () => config()['koios-url'];

const post = async (path, body) => {
  const r = await fetch(`${base()}/${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${path}: HTTP ${r.status} ${t}`);
  return JSON.parse(t);
};
const get = async (path) => {
  const r = await fetch(`${base()}/${path}`);
  const t = await r.text();
  if (!r.ok) throw new Error(`${path}: HTTP ${r.status} ${t}`);
  return JSON.parse(t);
};
export const tip = async () => (await get('tip'))[0];
export const rawAddressUtxos = (address) =>
  post('address_utxos', { _addresses: [address], _extended: true });

const toUtxo = (u) => ({
  txHash: u.tx_hash,
  outputIndex: u.tx_index,
  address: u.address,
  assets: Object.fromEntries([
    ['lovelace', BigInt(u.value)],
    ...(u.asset_list ?? []).map((a) => [a.policy_id + a.asset_name, BigInt(a.quantity)]),
  ]),
  datumHash: u.inline_datum ? undefined : (u.datum_hash ?? undefined),
  datum: u.inline_datum ? u.inline_datum.bytes : undefined,
  scriptRef: undefined,
});

export const provider = {
  async getProtocolParameters() {
    const p = (await get(`epoch_params?_epoch_no=${(await tip()).epoch_no}`))[0];
    const d = PROTOCOL_PARAMETERS_DEFAULT;
    return {
      protocolMajorVersion: p.protocol_major,
      protocolMinorVersion: p.protocol_minor,
      minFeeA: p.min_fee_a,
      minFeeB: p.min_fee_b,
      maxTxSize: p.max_tx_size,
      maxValSize: p.max_val_size,
      keyDeposit: BigInt(p.key_deposit),
      poolDeposit: BigInt(p.pool_deposit),
      drepDeposit: BigInt(p.drep_deposit),
      govActionDeposit: BigInt(p.gov_action_deposit),
      priceMem: p.price_mem,
      priceStep: p.price_step,
      maxTxExMem: BigInt(p.max_tx_ex_mem),
      maxTxExSteps: BigInt(p.max_tx_ex_steps),
      coinsPerUtxoByte: BigInt(p.coins_per_utxo_size),
      collateralPercentage: p.collateral_percent,
      maxCollateralInputs: p.max_collateral_inputs,
      minFeeRefScriptCostPerByte: p.min_fee_ref_script_cost_per_byte,
      // the devnet publishes cost models for PlutusV1 and PlutusV3 only; V2 falls back to Lucid's default (unused here)
      costModels: {
        PlutusV1: [...p.cost_models.PlutusV1],
        PlutusV2: p.cost_models.PlutusV2 ? [...p.cost_models.PlutusV2] : d.costModels.PlutusV2,
        PlutusV3: [...p.cost_models.PlutusV3],
      },
    };
  },
  async getUtxos(addr) {
    if (typeof addr !== 'string')
      throw new Error('credential lookups are not supported by this provider');
    return (await rawAddressUtxos(addr)).map(toUtxo);
  },
  async getUtxosWithUnit(addr, unit) {
    return (await this.getUtxos(addr)).filter((u) => u.assets[unit] > 0n);
  },
  async getUtxoByUnit(unit) {
    const live = await utxosWithUnit(unit);
    if (live.length !== 1) throw new Error(`unit ${unit}: ${live.length} live outputs`);
    return live[0];
  },
  async getUtxosByOutRef(refs) {
    const rows = await post('utxo_info', {
      _utxo_refs: refs.map((r) => `${r.txHash}#${r.outputIndex}`),
      _extended: true,
    });
    return rows.filter((r) => !r.is_spent).map(toUtxo);
  },
  async getDelegation() {
    return { poolId: null, rewards: 0n };
  },
  async getDatum() {
    throw new Error('getDatum is not supported (all datums here are inline)');
  },
  async awaitTx(txHash, interval = 300) {
    for (let i = 0; i < 600; i++) {
      const r = await post('tx_status', { _tx_hashes: [txHash] });
      if (r[0] && r[0].num_confirmations !== null && r[0].num_confirmations >= 1) return true;
      await new Promise((s) => setTimeout(s, interval));
    }
    return false;
  },
  async submitTx(cborHex) {
    const r = await fetch(`${base()}/submittx`, {
      method: 'POST',
      headers: { 'content-type': 'application/cbor' },
      body: Buffer.from(cborHex, 'hex'),
    });
    const t = await r.text();
    if (!r.ok) throw new Error(`submittx: HTTP ${r.status} ${t}`);
    return JSON.parse(t);
  },
  async evaluateTx() {
    throw new Error('the provider has no evaluate endpoint; use local evaluation');
  },
};

// live outputs holding one asset: unit = policy id + asset name, hex
export const utxosWithUnit = async (unit) => {
  const rows = await post('asset_utxos', {
    _asset_list: [[unit.slice(0, 56), unit.slice(56)]],
    _extended: true,
  });
  return rows.filter((r) => !r.is_spent).map(toUtxo);
};

export const makeLucid = async () => {
  const t = await tip(); // devnet slots are 100 ms
  return Lucid(provider, 'Custom', {
    slotConfig: { zeroTime: t.block_time * 1000 - t.abs_slot * 100, zeroSlot: 0, slotLength: 100 },
  });
};

export const hexToText = (h) => Buffer.from(h, 'hex').toString('utf8');
export const textToHex = (t) => Buffer.from(t, 'utf8').toString('hex');

// an Aiken Address, as Lucid decodes Plutus data, back to bech32
export const dataToAddress = (d) => {
  const cred = (c) => ({ type: c.index === 0 ? 'Key' : 'Script', hash: c.fields[0] });
  const stake = d.fields[1].index === 0 ? cred(d.fields[1].fields[0].fields[0]) : undefined;
  return credentialToAddress('Custom', cred(d.fields[0]), stake);
};
export { CML, Data, Constr, writeFileSync, readFileSync };
// all rows for outputs, spent ones included (a spent output answers with is_spent: true)
export const rawUtxoInfo = (refs) =>
  post('utxo_info', {
    _utxo_refs: refs.map((r) => `${r.txHash}#${r.outputIndex}`),
    _extended: true,
  });
export { toUtxo };
