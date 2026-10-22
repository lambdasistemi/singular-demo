//// A name sink: an address anyone can pay, whose funds can only be moved
//// to the address currently registered under one name in a Singular
//// open-datum registry.
////
//// Parameters (the sink is closed over all three):
////   active_policy  the registry's active policy, the policy of the key tokens
////   name           the registered key, e.g. "alice"
//// (The controller of the key is NOT a parameter: whoever holds the live key
//// `name` under `active_policy` is its controller, and the registry guarantees one.)
////
//// Datum: ignored, any datum or none. Redeemer: the output reference of
//// the registry output of the name, which the spending transaction must
//// carry as a REFERENCE input.
////
//// Each failing check ends the script with its own label:
////   sink-no-reference  sink-token  sink-envelope  sink-binding
////   sink-payload  sink-foreign-script  sink-datum-hash  sink-conservation

use aiken/collection/list
use cardano/address.{Address, Script}
use cardano/assets.{Value, flatten, merge, quantity_of, zero}
use cardano/transaction.{
  Datum, DatumHash, InlineDatum, Output, OutputReference, Transaction,
  find_input,
}

// The open-datum envelope as the registry writes it: Constr 0 [control, payload].
pub type StateAsset {
  statePolicy: ByteArray,
  stateName: ByteArray,
}

pub type Control {
  version: Int,
  registry: StateAsset,
  activePolicy: ByteArray,
  key: ByteArray,
  controller: ByteArray,
  deposit: Int,
}

pub type Envelope {
  control: Control,
  payload: Data,
}

validator sink(active_policy: ByteArray, name: ByteArray) {
  spend(
    _datum: Option<Data>,
    ref: OutputReference,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    // 1. the registry output is a reference input of this transaction
    let registry_output: Output =
      when list.find(tx.reference_inputs, fn(i) { i.output_reference == ref }) is {
        Some(input) -> input.output
        None -> fail @"sink-no-reference"
      }

    // 2. it holds exactly one token (active_policy, name)
    expect True =
      if quantity_of(registry_output.value, active_policy, name) == 1 {
        True
      } else {
        fail @"sink-token"
      }

    // 3. its inline datum is an envelope bound to this name and policy
    let envelope: Envelope =
      when envelope_of(registry_output.datum) is {
        Some(found) -> found
        None -> fail @"sink-envelope"
      }
    let control = envelope.control
    expect True =
      if control.key == name && control.activePolicy == active_policy {
        True
      } else {
        fail @"sink-binding"
      }

    // 4. the payload is the destination, an Aiken Address
    let destination: Address =
      when address_of(envelope.payload) is {
        Some(found) -> found
        None -> fail @"sink-payload"
      }

    // 6. (checked in the same pass as the sum below) every spent script input sits at our own address
    // 5. the sum of the spent inputs at our own address ...
    expect Some(own_input) = find_input(tx.inputs, own_ref)
    let own = own_input.output.address
    let spent: Value =
      list.foldl(
        tx.inputs,
        zero,
        fn(i, acc) {
          if i.output.address == own {
            merge(acc, i.output.value)
          } else {
            when i.output.address.payment_credential is {
              Script(_) -> fail @"sink-foreign-script"
              _ -> acc
            }
          }
        },
      )

    // 7. no output at our own address carries a datum hash: an unknown hash would lock the funds
    expect True =
      if list.all(tx.outputs, fn(o) { o.address != own || !is_datum_hash(o.datum) }) {
        True
      } else {
        fail @"sink-datum-hash"
      }

    // 5. ... must come back, per asset, to the sink or to the destination
    let returned: Value =
      list.foldl(
        tx.outputs,
        zero,
        fn(o, acc) {
          if o.address == own || o.address == destination {
            merge(acc, o.value)
          } else {
            acc
          }
        },
      )
    if conserved(spent, returned) {
      True
    } else {
      fail @"sink-conservation"
    }
  }

  else(_) {
    fail
  }
}

/// The envelope of an output, if it carries one inline (a soft cast: no compiler failure).
pub fn envelope_of(datum: Datum) -> Option<Envelope> {
  when datum is {
    InlineDatum(raw) ->
      if raw is envelope: Envelope {
        Some(envelope)
      } else {
        None
      }
    _ -> None
  }
}

/// The payload as an Address, if it is one.
pub fn address_of(payload: Data) -> Option<Address> {
  if payload is destination: Address {
    Some(destination)
  } else {
    None
  }
}

fn is_datum_hash(datum: Datum) -> Bool {
  when datum is {
    DatumHash(_) -> True
    _ -> False
  }
}

/// Per asset, ada included: what was spent is at most what was returned.
pub fn conserved(spent: Value, returned: Value) -> Bool {
  list.all(
    flatten(spent),
    fn((policy, asset, quantity)) {
      quantity <= quantity_of(returned, policy, asset)
    },
  )
}

test conserved_exact() {
  let v = assets.from_lovelace(5_000_000) |> assets.add("p", "n", 3)
  conserved(v, v)
}

test conserved_surplus_is_fine() {
  let spent = assets.from_lovelace(5_000_000)
  conserved(spent, assets.from_lovelace(6_000_000))
}

test lovelace_short_fails() {
  let spent = assets.from_lovelace(5_000_000)
  !conserved(spent, assets.from_lovelace(4_999_999))
}

test token_short_fails() {
  let spent = assets.from_lovelace(5_000_000) |> assets.add("p", "n", 3)
  let returned = assets.from_lovelace(9_000_000) |> assets.add("p", "n", 2)
  !conserved(spent, returned)
}

test other_token_does_not_count() {
  let spent = assets.from_lovelace(5_000_000) |> assets.add("p", "n", 3)
  let returned = assets.from_lovelace(9_000_000) |> assets.add("p", "other", 3)
  !conserved(spent, returned)
}
