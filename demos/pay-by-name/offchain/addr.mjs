// Address helpers. No packages: bech32 decoding by hand.
//   addrJson(addr)    the address as Aiken `cardano/address.Address`, Plutus-data JSON
//   addrKeyhash(addr) the 28-byte payment key hash (hex); throws if the payment part is a script
const C = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
const G = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
function decode(addr) {
  const i = addr.lastIndexOf('1'),
    hrp = addr.slice(0, i),
    d = [...addr.slice(i + 1)].map((c) => C.indexOf(c));
  let chk = 1;
  for (const v of [
    ...[...hrp].map((c) => c.charCodeAt(0) >> 5),
    0,
    ...[...hrp].map((c) => c.charCodeAt(0) & 31),
    ...d,
  ]) {
    const b = chk >> 25;
    chk = ((chk & 0x1ffffff) << 5) ^ v;
    for (let k = 0; k < 5; k++) if ((b >> k) & 1) chk ^= G[k];
  }
  if (i < 1 || chk !== 1 || d.some((v) => v < 0)) throw new Error('not a valid bech32 address');
  let acc = 0,
    bits = 0;
  const raw = [];
  for (const v of d.slice(0, -6)) {
    acc = (acc << 5) | v;
    bits += 5;
    while (bits >= 8) {
      bits -= 8;
      raw.push((acc >> bits) & 255);
      acc &= (1 << bits) - 1;
    }
  }
  return { raw, hex: Buffer.from(raw).toString('hex'), kind: raw[0] >> 4 };
}
export function addrJson(addr) {
  const { hex, kind } = decode(addr),
    hash = (o) => hex.slice(2 + o, 58 + o);
  if (![0, 1, 2, 3, 6, 7].includes(kind)) throw new Error(`unsupported address type ${kind}`);
  const cred = (script, h) => ({ constructor: script ? 1 : 0, fields: [{ bytes: h }] });
  const pay = cred(kind === 1 || kind === 3 || kind === 7, hash(0));
  const stake =
    kind < 4
      ? { constructor: 0, fields: [{ constructor: 0, fields: [cred(kind >= 2, hash(56))] }] }
      : { constructor: 1, fields: [] };
  return { constructor: 0, fields: [pay, stake] };
}
export function addrKeyhash(addr) {
  const { raw, kind } = decode(addr);
  if (kind & 1 || kind > 7)
    throw new Error('payment credential is a script (or not a payment address)');
  return Buffer.from(raw.slice(1, 29)).toString('hex');
}
