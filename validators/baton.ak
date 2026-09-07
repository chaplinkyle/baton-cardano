use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/interval.{Finite, Interval}
use aiken/primitive/bytearray
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{
  Datum, InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

/// Maximum transaction validity window accepted by the validator (15 minutes).
/// A bounded window prevents a transaction signed long ago from remaining valid.
const max_validity_window_ms: Int = 900_000

/// Defensive upper bound. The website may offer a smaller range.
const max_misses_to_release: Int = 1_000

/// Terminal payouts carry a different NFT so the active-state receipt can
/// never be returned to the validator with a fabricated datum after completion.
const terminal_receipt_name: AssetName = "BATON_COMPLETE"

/// Bearer plans mint this one-shot capability token alongside the active
/// receipt. Because both are governed by the seed-bound policy, the contract
/// can prove that exactly one recovery capability exists.
const recovery_receipt_name: AssetName = "BATON_RECOVERY"

/// Fixed destinations can be key or script addresses. V1 supports either no
/// datum or an exact inline datum; datum hashes are deliberately not supported.
pub type PayoutDatum {
  NoPayoutDatum
  InlinePayoutDatum(Data)
}

/// Bearer recovery lets possession of the separately held, one-shot recovery
/// token authorize release. The token is minted by this policy at creation and
/// is never held inside the vault.
pub type ReleasePolicy {
  FixedDestination { address: Address, datum: PayoutDatum }
  BearerRecovery { policy_id: PolicyId, asset_name: AssetName }
}

/// Canonical datum carried by the single receipt/state NFT.
pub type VaultDatum {
  schema_version: Int,
  owner: VerificationKeyHash,
  liveness: VerificationKeyHash,
  check_in_period_ms: Int,
  misses_to_release: Int,
  last_check_in_at_ms: Int,
  release_policy: ReleasePolicy,
  sequence: Int,
  payload_commitment: Option<ByteArray>,
}

pub type MintAction {
  MintReceipt
  FinalizeReceipt
}

pub type Action {
  /// Recreate the canonical state output with a later check-in anchor.
  Pulse { new_check_in_at_ms: Int }
  /// Owner-only withdrawal while the vault is still live.
  Close
  /// Permissionless for fixed destinations; recovery-token-gated for bearer mode.
  Release { payout_address: Address }
}

/// The first instant at which Release is valid.
pub fn release_at(datum: VaultDatum) -> Int {
  datum.last_check_in_at_ms + datum.check_in_period_ms * datum.misses_to_release
}

fn finite_bounded_window(range: Interval) -> Pair<Int, Int> {
  expect Finite(lower) = range.lower_bound.bound_type
  expect Finite(upper) = range.upper_bound.bound_type
  expect range.lower_bound.is_inclusive
  expect False = range.upper_bound.is_inclusive
  expect upper > lower
  expect upper - lower <= max_validity_window_ms
  Pair(lower, upper)
}

fn receipt_quantity(
  value: Value,
  policy_id: PolicyId,
  receipt_name: AssetName,
) -> Int {
  assets.quantity_of(value, policy_id, receipt_name)
}

fn outputs_with_receipt(
  outputs: List<Output>,
  policy_id: PolicyId,
  receipt_name: AssetName,
) -> List<Output> {
  outputs
    |> list.filter(
        fn(output) {
          receipt_quantity(output.value, policy_id, receipt_name) == 1
        },
      )
}

fn only_receipt_output(
  outputs: List<Output>,
  policy_id: PolicyId,
  receipt_name: AssetName,
) -> Output {
  expect [output] = outputs_with_receipt(outputs, policy_id, receipt_name)
  output
}

fn policy_token_count(value: Value, policy_id: PolicyId) -> Int {
  value
    |> assets.tokens(policy_id)
    |> dict.to_pairs()
    |> list.length()
}

fn terminal_mint_is_exact(
  mint: Value,
  policy_id: PolicyId,
  receipt_name: AssetName,
) -> Bool {
  and {
    policy_token_count(mint, policy_id) == 2,
    receipt_quantity(mint, policy_id, receipt_name) == -1,
    receipt_quantity(mint, policy_id, terminal_receipt_name) == 1,
  }
}

fn initial_mint_is_exact(
  mint: Value,
  policy_id: PolicyId,
  receipt_name: AssetName,
  release_policy: ReleasePolicy,
) -> Bool {
  when release_policy is {
    FixedDestination { .. } -> and {
        policy_token_count(mint, policy_id) == 1,
        receipt_quantity(mint, policy_id, receipt_name) == 1,
      }
    BearerRecovery { .. } -> and {
        policy_token_count(mint, policy_id) == 2,
        receipt_quantity(mint, policy_id, receipt_name) == 1,
        receipt_quantity(mint, policy_id, recovery_receipt_name) == 1,
      }
  }
}

fn terminal_output(outputs: List<Output>, policy_id: PolicyId) -> Output {
  only_receipt_output(outputs, policy_id, terminal_receipt_name)
}

fn finalized_value(
  active_value: Value,
  policy_id: PolicyId,
  receipt_name: AssetName,
) -> Value {
  active_value
    |> assets.merge(assets.from_asset(policy_id, receipt_name, -1))
    |> assets.merge(assets.from_asset(policy_id, terminal_receipt_name, 1))
}

fn inline_vault_datum(output: Output) -> VaultDatum {
  expect InlineDatum(raw_datum) = output.datum
  expect datum: VaultDatum = raw_datum
  datum
}

fn valid_release_policy(
  policy: ReleasePolicy,
  vault_value: Value,
  receipt_policy: PolicyId,
  receipt_name: AssetName,
) -> Bool {
  when policy is {
    FixedDestination { address, .. } ->
      address.payment_credential != Script(receipt_policy)
    BearerRecovery { policy_id, asset_name } -> and {
        policy_id == receipt_policy,
        asset_name == recovery_receipt_name,
        receipt_name != recovery_receipt_name,
        assets.quantity_of(vault_value, receipt_policy, recovery_receipt_name) == 0,
      }
  }
}

/// Version one commits only SHA-256 digests. Keeping the optional commitment
/// fixed-width prevents a direct contract user from creating an unexpectedly
/// large datum that the official interface would never produce.
fn valid_payload_commitment(commitment: Option<ByteArray>) -> Bool {
  when commitment is {
    None -> True
    Some(digest) -> bytearray.length(digest) == 32
  }
}

fn valid_initial_datum(
  datum: VaultDatum,
  vault_value: Value,
  receipt_policy: PolicyId,
  receipt_name: AssetName,
  creation_anchor: Int,
) -> Bool {
  let supported_version = datum.schema_version == 1
  let distinct_keys = datum.owner != datum.liveness
  let valid_period = datum.check_in_period_ms > 0
  let valid_miss_floor = datum.misses_to_release >= 1
  let valid_miss_ceiling = datum.misses_to_release <= max_misses_to_release
  let valid_anchor = datum.last_check_in_at_ms == creation_anchor
  let initial_sequence = datum.sequence == 0
  let valid_policy = valid_release_policy(
    datum.release_policy,
    vault_value,
    receipt_policy,
    receipt_name,
  )
  let valid_commitment = valid_payload_commitment(datum.payload_commitment)
  and {
    supported_version?,
    distinct_keys?,
    valid_period?,
    valid_miss_floor?,
    valid_miss_ceiling?,
    valid_anchor?,
    initial_sequence?,
    valid_policy?,
    valid_commitment?,
  }
}

fn expected_payout_datum(expected: PayoutDatum, actual: Datum) -> Bool {
  when expected is {
    NoPayoutDatum -> actual == NoDatum
    InlinePayoutDatum(data) -> actual == InlineDatum(data)
  }
}

fn input_asset_quantity(
  inputs: List<Input>,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Int {
  inputs
    |> list.foldl(
        0,
        fn(input, total) {
          total + assets.quantity_of(input.output.value, policy_id, asset_name)
        },
      )
}

fn pulse_is_valid(
  old_datum: VaultDatum,
  new_check_in_at_ms: Int,
  own_input: Output,
  receipt_output: Output,
  tx: Transaction,
) -> Bool {
  let Pair(_, validity_upper) = finite_bounded_window(tx.validity_range)
  let new_datum = inline_vault_datum(receipt_output)
  let expected_datum = VaultDatum {
    ..old_datum,
    last_check_in_at_ms: new_check_in_at_ms,
    sequence: old_datum.sequence + 1,
  }
  let liveness_signed = list.has(tx.extra_signatories, old_datum.liveness)
  let before_release = tx.validity_range
    |> interval.is_entirely_before(release_at(old_datum))
  let anchor_matches_upper = new_check_in_at_ms == validity_upper
  let anchor_advances = new_check_in_at_ms > old_datum.last_check_in_at_ms
  let same_address = receipt_output.address == own_input.address
  let same_value = receipt_output.value == own_input.value
  let same_reference_script = receipt_output.reference_script == own_input.reference_script
  let datum_transition = new_datum == expected_datum

  and {
    liveness_signed?,
    before_release?,
    anchor_matches_upper?,
    anchor_advances?,
    same_address?,
    same_value?,
    same_reference_script?,
    datum_transition?,
  }
}

fn close_is_valid(
  old_datum: VaultDatum,
  own_input: Output,
  payout_output: Output,
  receipt_policy: PolicyId,
  receipt_name: AssetName,
  tx: Transaction,
) -> Bool {
  let Pair(validity_lower, validity_upper) = finite_bounded_window(
    tx.validity_range,
  )
  and {
    validity_upper > validity_lower,
    list.has(tx.extra_signatories, old_datum.owner),
    tx.validity_range |> interval.is_entirely_before(release_at(old_datum)),
    payout_output.address.payment_credential == VerificationKey(old_datum.owner),
    payout_output.value == finalized_value(
      own_input.value,
      receipt_policy,
      receipt_name,
    ),
  }
}

fn release_is_valid(
  old_datum: VaultDatum,
  payout_address: Address,
  own_input: Output,
  payout_output: Output,
  receipt_policy: ScriptHash,
  receipt_name: AssetName,
  tx: Transaction,
) -> Bool {
  let Pair(validity_lower, _) = finite_bounded_window(tx.validity_range)
  expect validity_lower >= release_at(old_datum)

  when old_datum.release_policy is {
    FixedDestination { address, datum } -> and {
        payout_address == address,
        payout_output.address == address,
        payout_output.value == finalized_value(
          own_input.value,
          receipt_policy,
          receipt_name,
        ),
        expected_payout_datum(datum, payout_output.datum),
      }
    BearerRecovery { policy_id, asset_name } -> {
      let recovery_token = assets.from_asset(policy_id, asset_name, 1)
      let terminal_value = finalized_value(
        own_input.value,
        receipt_policy,
        receipt_name,
      )
      and {
        assets.quantity_of(own_input.value, policy_id, asset_name) == 0,
        assets.quantity_of(tx.mint, policy_id, asset_name) == 0,
        input_asset_quantity(tx.inputs, policy_id, asset_name) == 1,
        payout_address.payment_credential != Script(receipt_policy),
        payout_output.address == payout_address,
        payout_output.value == assets.merge(terminal_value, recovery_token),
      }
    }
  }
}

/// A single parameterized script is both the one-shot receipt minting policy and
/// the spending validator. Its hash therefore identifies the state NFT policy.
validator baton(seed: OutputReference, receipt_name: AssetName) {
  mint(redeemer: MintAction, policy_id: PolicyId, tx: Transaction) {
    when redeemer is {
      MintReceipt -> {
        expect and {
            receipt_name != terminal_receipt_name,
            receipt_name != recovery_receipt_name,
          }
        expect list.any(tx.inputs, fn(input) { input.output_reference == seed })

        let Pair(_, creation_anchor) = finite_bounded_window(tx.validity_range)
        let receipt_output = only_receipt_output(
          tx.outputs,
          policy_id,
          receipt_name,
        )
        expect Script(output_script_hash) = receipt_output.address.payment_credential
        expect output_script_hash == policy_id
        let initial_datum = inline_vault_datum(receipt_output)
        let owner_signed = list.has(tx.extra_signatories, initial_datum.owner)
        let mint_is_exact = initial_mint_is_exact(
          tx.mint,
          policy_id,
          receipt_name,
          initial_datum.release_policy,
        )
        let recovery_delivery_is_valid = when initial_datum.release_policy is {
          FixedDestination { .. } -> True
          BearerRecovery { .. } -> {
            let recovery_output = only_receipt_output(
              tx.outputs,
              policy_id,
              recovery_receipt_name,
            )
            and {
              recovery_output.address.payment_credential == VerificationKey(
                initial_datum.owner,
              ),
              receipt_quantity(recovery_output.value, policy_id, receipt_name) == 0,
              receipt_quantity(
                recovery_output.value,
                policy_id,
                terminal_receipt_name,
              ) == 0,
            }
          }
        }
        let initial_config_valid = valid_initial_datum(
          initial_datum,
          receipt_output.value,
          policy_id,
          receipt_name,
          creation_anchor,
        )

        and {
          owner_signed?,
          mint_is_exact?,
          recovery_delivery_is_valid?,
          initial_config_valid?,
        }
      }
      FinalizeReceipt -> {
        expect [active_input] = tx.inputs
          |> list.filter(
              fn(input) {
                and {
                  input.output.address.payment_credential == Script(policy_id),
                  receipt_quantity(input.output.value, policy_id, receipt_name) == 1,
                  receipt_quantity(
                    input.output.value,
                    policy_id,
                    terminal_receipt_name,
                  ) == 0,
                }
              },
            )
        let delivered_terminal = terminal_output(tx.outputs, policy_id)
        and {
          active_input.output_reference != seed,
          receipt_quantity(
            delivered_terminal.value,
            policy_id,
            terminal_receipt_name,
          ) == 1,
          terminal_mint_is_exact(tx.mint, policy_id, receipt_name),
        }
      }
    }
  }

  spend(
    datum: Option<VaultDatum>,
    redeemer: Action,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    expect Some(old_datum) = datum
    let own_input = tx.inputs |> transaction.resolve_input(own_ref)
    expect Script(receipt_policy) = own_input.address.payment_credential
    expect receipt_quantity(own_input.value, receipt_policy, receipt_name) == 1
    expect
      receipt_quantity(own_input.value, receipt_policy, terminal_receipt_name) == 0

    when redeemer is {
      Pulse { new_check_in_at_ms } -> {
        expect policy_token_count(tx.mint, receipt_policy) == 0
        let receipt_output = only_receipt_output(
          tx.outputs,
          receipt_policy,
          receipt_name,
        )
        pulse_is_valid(
          old_datum,
          new_check_in_at_ms,
          own_input,
          receipt_output,
          tx,
        )
      }
      Close -> {
        expect terminal_mint_is_exact(tx.mint, receipt_policy, receipt_name)
        let payout_output = terminal_output(tx.outputs, receipt_policy)
        close_is_valid(
          old_datum,
          own_input,
          payout_output,
          receipt_policy,
          receipt_name,
          tx,
        )
      }
      Release { payout_address } -> {
        expect terminal_mint_is_exact(tx.mint, receipt_policy, receipt_name)
        let payout_output = terminal_output(tx.outputs, receipt_policy)
        release_is_valid(
          old_datum,
          payout_address,
          own_input,
          payout_output,
          receipt_policy,
          receipt_name,
          tx,
        )
      }
    }
  }

  else(_) {
    fail
  }
}
