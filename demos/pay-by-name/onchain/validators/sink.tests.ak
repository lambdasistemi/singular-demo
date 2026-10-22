//// Validator-level tests: one accepting control and, beside it, refusals that move exactly one fact.
//// The refusal tests are marked `fail`; scripts/00b-label-tests.sh strips the marker in a scratch copy
//// and checks that each one fails with the label in its name.

use cardano/address.{Address}
use cardano/assets
use cardano/transaction.{
  DatumHash, InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use sink.{Control, Envelope, StateAsset}
use sink as sink_module

const active_policy: ByteArray = #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const name: ByteArray = "alice"

const controller: ByteArray = #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const sink_hash: ByteArray = #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

const own_ref: OutputReference =
  OutputReference {
    transaction_id: #"0101010101010101010101010101010101010101010101010101010101010101",
    output_index: 0,
  }

const registry_ref: OutputReference =
  OutputReference {
    transaction_id: #"0202020202020202020202020202020202020202020202020202020202020202",
    output_index: 1,
  }

fn destination() -> Address {
  address.from_verification_key(
    #"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  )
}

fn envelope(payload: Data) -> Envelope {
  Envelope {
    control: Control {
      version: 1,
      registry: StateAsset { statePolicy: #"11", stateName: #"22" },
      activePolicy: active_policy,
      key: name,
      controller,
      deposit: 2_000_000,
    },
    payload,
  }
}

fn registry_input(datum: Data) -> Input {
  Input {
    output_reference: registry_ref,
    output: Output {
      address: address.from_script(#"ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"),
      value: assets.from_lovelace(2_000_000) |> assets.add(active_policy, name, 1),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

/// 10 ada in the sink: 7 to the destination, 3 back to the sink under `continuing`.
fn move(registry: Input, continuing: transaction.Datum) -> Bool {
  let own_address = address.from_script(sink_hash)
  let tx =
    Transaction {
      ..transaction.placeholder,
      inputs: [
        Input {
          output_reference: own_ref,
          output: Output {
            address: own_address,
            value: assets.from_lovelace(10_000_000),
            datum: NoDatum,
            reference_script: None,
          },
        },
      ],
      reference_inputs: [registry],
      outputs: [
        Output {
          address: destination(),
          value: assets.from_lovelace(7_000_000),
          datum: NoDatum,
          reference_script: None,
        },
        Output {
          address: own_address,
          value: assets.from_lovelace(3_000_000),
          datum: continuing,
          reference_script: None,
        },
      ],
    }
  sink_module.sink.spend(active_policy, name, None, registry_ref, own_ref, tx)
}

fn honest() -> Input {
  registry_input(envelope(destination()))
}

test accepts_honest_move() {
  move(honest(), NoDatum)
}

test accepts_continuing_inline_datum() {
  move(honest(), InlineDatum(42))
}

test refuses_sink_envelope_datum_is_not_an_envelope() fail {
  move(registry_input(42), NoDatum)
}

test refuses_sink_envelope_no_inline_datum() fail {
  let h = honest()
  move(Input { ..h, output: Output { ..h.output, datum: NoDatum } }, NoDatum)
}

test refuses_sink_payload_is_not_an_address() fail {
  move(registry_input(envelope(42)), NoDatum)
}

test refuses_sink_datum_hash_public() fail {
  move(honest(), DatumHash(#"1212121212121212121212121212121212121212121212121212121212121212"))
}

test accepts_any_controller_in_the_envelope() {
  let e = envelope(destination())
  let other = Envelope { ..e, control: Control { ..e.control, controller: #"99999999999999999999999999999999999999999999999999999999" } }
  move(registry_input(other), NoDatum)
}
