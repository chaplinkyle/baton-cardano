use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/fuzz
use aiken/interval.{
  Finite, Interval, IntervalBound, NegativeInfinity, PositiveInfinity,
}
use baton
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{
  DatumHash, InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

const seed_ref: OutputReference =
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000001",
    output_index: 0,
  }

const own_ref: OutputReference =
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000002",
    output_index: 0,
  }

const recovery_ref: OutputReference =
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000003",
    output_index: 0,
  }

const second_recovery_ref: OutputReference =
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000005",
    output_index: 0,
  }

const second_own_ref: OutputReference =
  OutputReference {
    transaction_id: #"0000000000000000000000000000000000000000000000000000000000000004",
    output_index: 0,
  }

const receipt_policy: ScriptHash =
  #"11111111111111111111111111111111111111111111111111111111"

const recovery_policy: PolicyId =
  #"22222222222222222222222222222222222222222222222222222222"

const second_receipt_policy: ScriptHash =
  #"33333333333333333333333333333333333333333333333333333333"

const owner: VerificationKeyHash =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const liveness: VerificationKeyHash =
  #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

const beneficiary: VerificationKeyHash =
  #"cccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

const receipt_name: AssetName = "BATON"

const terminal_receipt_name: AssetName = "BATON_COMPLETE"

const unexpected_name: AssetName = "UNEXPECTED"

const recovery_name: AssetName = "BATON_RECOVERY"

const second_receipt_name: AssetName = "BATON_TWO"

fn owner_address() -> Address {
  Address { payment_credential: VerificationKey(owner), stake_credential: None }
}

fn beneficiary_address() -> Address {
  Address {
    payment_credential: VerificationKey(beneficiary),
    stake_credential: None,
  }
}

fn script_address() -> Address {
  Address { payment_credential: Script(receipt_policy), stake_credential: None }
}

fn second_script_address() -> Address {
  Address {
    payment_credential: Script(second_receipt_policy),
    stake_credential: None,
  }
}

fn validity_window(lower: Int, upper: Int) -> Interval {
  Interval {
    lower_bound: IntervalBound { bound_type: Finite(lower), is_inclusive: True },
    upper_bound: IntervalBound {
      bound_type: Finite(upper),
      is_inclusive: False,
    },
  }
}

fn fixed_datum() -> baton.VaultDatum {
  baton.VaultDatum {
    schema_version: 1,
    owner,
    liveness,
    check_in_period_ms: 10_000,
    misses_to_release: 3,
    last_check_in_at_ms: 1_000,
    release_policy: baton.FixedDestination {
      address: beneficiary_address(),
      datum: baton.NoPayoutDatum,
    },
    sequence: 0,
    payload_commitment: None,
  }
}

fn bearer_datum() -> baton.VaultDatum {
  baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.BearerRecovery {
      policy_id: receipt_policy,
      asset_name: recovery_name,
    },
  }
}

fn vault_value() -> Value {
  assets.merge(
    assets.from_lovelace(50_000_000),
    assets.from_asset(receipt_policy, receipt_name, 1),
  )
}

fn terminal_value() -> Value {
  assets.merge(
    assets.from_lovelace(50_000_000),
    assets.from_asset(receipt_policy, terminal_receipt_name, 1),
  )
}

fn terminal_mint() -> Value {
  assets.merge(
    assets.from_asset(receipt_policy, receipt_name, -1),
    assets.from_asset(receipt_policy, terminal_receipt_name, 1),
  )
}

fn second_vault_value() -> Value {
  assets.merge(
    assets.from_lovelace(60_000_000),
    assets.from_asset(second_receipt_policy, second_receipt_name, 1),
  )
}

fn vault_output(datum: baton.VaultDatum, value: Value) -> Output {
  Output {
    address: script_address(),
    value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn plain_output(address: Address, value: Value) -> Output {
  Output { address, value, datum: NoDatum, reference_script: None }
}

fn seed_input() -> Input {
  Input {
    output_reference: seed_ref,
    output: plain_output(owner_address(), assets.from_lovelace(3_000_000)),
  }
}

fn own_input(datum: baton.VaultDatum) -> Input {
  Input {
    output_reference: own_ref,
    output: vault_output(datum, vault_value()),
  }
}

fn second_vault_output(datum: baton.VaultDatum, value: Value) -> Output {
  Output {
    address: second_script_address(),
    value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

fn second_own_input(datum: baton.VaultDatum) -> Input {
  Input {
    output_reference: second_own_ref,
    output: second_vault_output(datum, second_vault_value()),
  }
}

fn recovery_input() -> Input {
  Input {
    output_reference: recovery_ref,
    output: plain_output(
      owner_address(),
      assets.merge(
        assets.from_lovelace(2_000_000),
        assets.from_asset(receipt_policy, recovery_name, 1),
      ),
    ),
  }
}

fn recovery_output(address: Address, quantity: Int) -> Output {
  plain_output(
    address,
    assets.merge(
      assets.from_lovelace(2_000_000),
      assets.from_asset(receipt_policy, recovery_name, quantity),
    ),
  )
}

fn bearer_creation_mint() -> Value {
  assets.merge(
    assets.from_asset(receipt_policy, receipt_name, 1),
    assets.from_asset(receipt_policy, recovery_name, 1),
  )
}

fn mint_tx(datum: baton.VaultDatum) -> Transaction {
  let Pair(outputs, minted) = when datum.release_policy is {
    baton.FixedDestination { .. } ->
      Pair(
        [vault_output(datum, vault_value())],
        assets.from_asset(receipt_policy, receipt_name, 1),
      )
    baton.BearerRecovery { .. } ->
      Pair(
        [
          vault_output(datum, vault_value()),
          recovery_output(owner_address(), 1),
        ],
        bearer_creation_mint(),
      )
  }
  Transaction {
    ..transaction.placeholder,
    inputs: [seed_input()],
    outputs,
    mint: minted,
    validity_range: validity_window(0, 1_000),
    extra_signatories: [owner],
  }
}

fn pulse_tx(
  old_datum: baton.VaultDatum,
  new_datum: baton.VaultDatum,
) -> Transaction {
  Transaction {
    ..transaction.placeholder,
    inputs: [own_input(old_datum)],
    outputs: [vault_output(new_datum, vault_value())],
    validity_range: validity_window(1_500, 2_000),
    extra_signatories: [liveness],
  }
}

fn fixed_release_tx(
  datum: baton.VaultDatum,
  address: Address,
  lower: Int,
) -> Transaction {
  Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(address, terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(lower, lower + 500),
  }
}

fn bearer_release_tx(datum: baton.VaultDatum) -> Transaction {
  let payout_value = assets.merge(
    terminal_value(),
    assets.from_asset(receipt_policy, recovery_name, 1),
  )
  Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum), recovery_input()],
    outputs: [plain_output(beneficiary_address(), payout_value)],
    mint: terminal_mint(),
    validity_range: validity_window(31_000, 31_500),
  }
}

fn pulse_tx_at(
  old_datum: baton.VaultDatum,
  new_datum: baton.VaultDatum,
  lower: Int,
  upper: Int,
) -> Transaction {
  Transaction {
    ..transaction.placeholder,
    inputs: [own_input(old_datum)],
    outputs: [vault_output(new_datum, vault_value())],
    validity_range: validity_window(lower, upper),
    extra_signatories: [liveness],
  }
}

fn datum_after_pulses(
  datum: baton.VaultDatum,
  remaining: Int,
) -> baton.VaultDatum {
  if remaining == 0 {
    datum
  } else {
    datum_after_pulses(
      baton.VaultDatum {
        ..datum,
        last_check_in_at_ms: datum.last_check_in_at_ms + 500,
        sequence: datum.sequence + 1,
      },
      remaining - 1,
    )
  }
}

fn pulse_sequence_is_valid(datum: baton.VaultDatum, remaining: Int) -> Bool {
  if remaining == 0 {
    True
  } else {
    let new_anchor = datum.last_check_in_at_ms + 500
    let new_datum = baton.VaultDatum {
      ..datum,
      last_check_in_at_ms: new_anchor,
      sequence: datum.sequence + 1,
    }
    and {
      baton.baton.spend(
        seed_ref,
        receipt_name,
        Some(datum),
        baton.Pulse { new_check_in_at_ms: new_anchor },
        own_ref,
        pulse_tx_at(datum, new_datum, datum.last_check_in_at_ms, new_anchor),
      ),
      pulse_sequence_is_valid(new_datum, remaining - 1),
    }
  }
}

test release_time_multiplies_period_by_allowed_misses() {
  baton.release_at(fixed_datum()) == 31_000
}

test mint_accepts_valid_configurable_threshold() {
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(fixed_datum()),
  )
}

test mint_accepts_one_shot_bearer_recovery_token() {
  let datum = bearer_datum()
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test bearer_mint_rejects_missing_recovery_token_mint() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..mint_tx(datum),
    mint: assets.from_asset(receipt_policy, receipt_name, 1),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test bearer_mint_rejects_two_recovery_tokens() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..mint_tx(datum),
    outputs: [
      vault_output(datum, vault_value()),
      recovery_output(owner_address(), 2),
    ],
    mint: assets.merge(
      assets.from_asset(receipt_policy, receipt_name, 1),
      assets.from_asset(receipt_policy, recovery_name, 2),
    ),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test bearer_mint_rejects_extra_policy_asset() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..mint_tx(datum),
    mint: assets.merge(
      bearer_creation_mint(),
      assets.from_asset(receipt_policy, unexpected_name, 1),
    ),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test bearer_mint_rejects_recovery_token_sent_to_another_key() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..mint_tx(datum),
    outputs: [
      vault_output(datum, vault_value()),
      recovery_output(beneficiary_address(), 1),
    ],
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test fixed_mint_rejects_unrequested_recovery_token() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..mint_tx(datum),
    outputs: [
      vault_output(datum, vault_value()),
      recovery_output(owner_address(), 1),
    ],
    mint: bearer_creation_mint(),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_accepts_sha256_payload_commitment() {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    payload_commitment: Some(
      #"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    ),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_short_payload_commitment() fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    payload_commitment: Some(
      #"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e",
    ),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_long_payload_commitment() fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    payload_commitment: Some(
      #"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
    ),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_completion_name_as_active_receipt_parameter() fail {
  let datum = fixed_datum()
  let value = assets.merge(
    assets.from_lovelace(50_000_000),
    assets.from_asset(receipt_policy, terminal_receipt_name, 1),
  )
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [seed_input()],
    outputs: [vault_output(datum, value)],
    mint: assets.from_asset(receipt_policy, terminal_receipt_name, 1),
    validity_range: validity_window(0, 1_000),
    extra_signatories: [owner],
  }
  baton.baton.mint(
    seed_ref,
    terminal_receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_recovery_name_as_active_receipt_parameter() fail {
  let datum = fixed_datum()
  let value = assets.merge(
    assets.from_lovelace(50_000_000),
    assets.from_asset(receipt_policy, recovery_name, 1),
  )
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [seed_input()],
    outputs: [vault_output(datum, value)],
    mint: assets.from_asset(receipt_policy, recovery_name, 1),
    validity_range: validity_window(0, 1_000),
    extra_signatories: [owner],
  }
  baton.baton.mint(
    seed_ref,
    recovery_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_completion_receipt_as_recovery_credential() fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.BearerRecovery {
      policy_id: receipt_policy,
      asset_name: terminal_receipt_name,
    },
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test prop_release_time_matches_generated_schedule(
  ((period, misses), anchor) via fuzz.both(
    fuzz.both(fuzz.int_between(1, 3_153_600_000), fuzz.int_between(1, 1_000)),
    fuzz.int_between(0, 4_102_444_800_000),
  ),
) {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    check_in_period_ms: period,
    misses_to_release: misses,
    last_check_in_at_ms: anchor,
  }
  baton.release_at(datum) == anchor + period * misses
}

test prop_fixed_release_accepts_generated_exact_boundary(
  (period, misses) via fuzz.both(
    fuzz.int_between(1, 3_153_600_000),
    fuzz.int_between(1, 1_000),
  ),
) {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    check_in_period_ms: period,
    misses_to_release: misses,
  }
  let boundary = baton.release_at(datum)
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    fixed_release_tx(datum, beneficiary_address(), boundary),
  )
}

test prop_fixed_release_rejects_generated_millisecond_before_boundary(
  (period, misses) via fuzz.both(
    fuzz.int_between(1, 3_153_600_000),
    fuzz.int_between(1, 1_000),
  ),
) fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    check_in_period_ms: period,
    misses_to_release: misses,
  }
  let too_early = baton.release_at(datum) - 1
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    fixed_release_tx(datum, beneficiary_address(), too_early),
  )
}

test prop_generated_pulse_sequence_reaches_valid_terminal_state(
  (steps, misses) via fuzz.both(
    fuzz.int_between(1, 20),
    fuzz.int_between(1, 1_000),
  ),
) {
  let initial = baton.VaultDatum {
    ..fixed_datum(),
    check_in_period_ms: 1_000,
    misses_to_release: misses,
  }
  let final = datum_after_pulses(initial, steps)
  and {
    pulse_sequence_is_valid(initial, steps),
    final.sequence == steps,
    final.last_check_in_at_ms == initial.last_check_in_at_ms + steps * 500,
    baton.baton.spend(
      seed_ref,
      receipt_name,
      Some(final),
      baton.Release { payout_address: beneficiary_address() },
      own_ref,
      fixed_release_tx(final, beneficiary_address(), baton.release_at(final)),
    ),
  }
}

test mint_rejects_zero_allowed_misses() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), misses_to_release: 0 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_same_owner_and_liveness_key() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), liveness: owner }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_missing_owner_signature() fail {
  let tx = Transaction { ..mint_tx(fixed_datum()), extra_signatories: [] }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_missing_one_shot_seed() fail {
  let tx = Transaction { ..mint_tx(fixed_datum()), inputs: [] }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_fixed_destination_back_to_vault_script() fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.FixedDestination {
      address: script_address(),
      datum: baton.NoPayoutDatum,
    },
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test pulse_preserves_value_and_advances_sequence() {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_missing_liveness_signature() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    extra_signatories: [],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_a_changed_miss_threshold() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    misses_to_release: 4,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_value_leaving_the_vault() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let reduced_value = assets.merge(
    assets.from_lovelace(49_000_000),
    assets.from_asset(receipt_policy, receipt_name, 1),
  )
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    outputs: [vault_output(new_datum, reduced_value)],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_at_the_release_boundary() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 31_500,
    sequence: 1,
  }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    validity_range: validity_window(31_000, 31_500),
    outputs: [vault_output(new_datum, vault_value())],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 31_500 },
    own_ref,
    tx,
  )
}

test owner_can_close_before_release() {
  let datum = fixed_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(2_000, 2_500),
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test bearer_owner_can_close_before_release_without_recovery_token() {
  let datum = bearer_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(2_000, 2_500),
    extra_signatories: [owner],
  }
  and {
    baton.baton.spend(
      seed_ref,
      receipt_name,
      Some(datum),
      baton.Close,
      own_ref,
      tx,
    ),
    baton.baton.mint(
      seed_ref,
      receipt_name,
      baton.FinalizeReceipt,
      receipt_policy,
      tx,
    ),
  }
}

test owner_cannot_close_at_release_boundary() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(31_000, 31_500),
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test close_rejects_overly_wide_validity_window() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(-1_000_000, 0),
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test close_rejects_unbounded_lower_validity_range() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: Interval {
      lower_bound: IntervalBound {
        bound_type: NegativeInfinity,
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(2_500),
        is_inclusive: False,
      },
    },
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test fixed_release_accepts_exact_boundary() {
  let datum = fixed_datum()
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    fixed_release_tx(datum, beneficiary_address(), 31_000),
  )
}

test fixed_release_rejects_one_millisecond_early() fail {
  let datum = fixed_datum()
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    fixed_release_tx(datum, beneficiary_address(), 30_999),
  )
}

test fixed_release_rejects_wrong_destination() fail {
  let datum = fixed_datum()
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    fixed_release_tx(datum, owner_address(), 31_000),
  )
}

test bearer_release_needs_no_listed_beneficiary() {
  let datum = bearer_datum()
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    bearer_release_tx(datum),
  )
}

test bearer_release_rejects_missing_recovery_token() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..bearer_release_tx(datum),
    inputs: [own_input(datum)],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test bearer_release_rejects_recovery_token_minted_in_same_transaction() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..bearer_release_tx(datum),
    mint: assets.from_asset(recovery_policy, recovery_name, 1),
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test bearer_release_rejects_payout_back_to_vault_script() fail {
  let datum = bearer_datum()
  let payout_value = assets.merge(
    vault_value(),
    assets.from_asset(recovery_policy, recovery_name, 1),
  )
  let tx = Transaction {
    ..bearer_release_tx(datum),
    outputs: [plain_output(script_address(), payout_value)],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: script_address() },
    own_ref,
    tx,
  )
}

test spend_rejects_duplicate_receipt_outputs() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let output = vault_output(new_datum, vault_value())
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    outputs: [output, output],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test spend_rejects_overly_wide_validity_window() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 902_000,
    sequence: 1,
  }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    outputs: [vault_output(new_datum, vault_value())],
    validity_range: validity_window(1_000, 902_000),
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 902_000 },
    own_ref,
    tx,
  )
}

test mint_rejects_unsupported_datum_version() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), schema_version: 2 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_zero_check_in_period() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), check_in_period_ms: 0 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_miss_threshold_above_protocol_limit() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), misses_to_release: 1_001 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_anchor_different_from_validity_upper() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), last_check_in_at_ms: 999 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_nonzero_initial_sequence() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), sequence: 1 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_recovery_token_inside_vault() fail {
  let datum = bearer_datum()
  let value = vault_value()
    |> assets.merge(assets.from_asset(receipt_policy, recovery_name, 1))
  let tx = Transaction {
    ..mint_tx(datum),
    outputs: [vault_output(datum, value)],
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_external_recovery_asset() fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.BearerRecovery {
      policy_id: recovery_policy,
      asset_name: unexpected_name,
    },
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_receipt_nft_as_recovery_credential() fail {
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.BearerRecovery {
      policy_id: receipt_policy,
      asset_name: receipt_name,
    },
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test pulse_rejects_owner_signature_without_liveness_signature() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_changed_owner() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    owner: beneficiary,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_changed_period() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    check_in_period_ms: 20_000,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_wrong_sequence_increment() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 2,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_anchor_not_equal_to_validity_upper() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 1_999,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 1_999 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_nonadvancing_anchor() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum { ..old_datum, sequence: 1 }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    validity_range: validity_window(500, 1_000),
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 1_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_value_added_to_canonical_state() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let increased_value = assets.merge(
    assets.from_lovelace(51_000_000),
    assets.from_asset(receipt_policy, receipt_name, 1),
  )
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    outputs: [vault_output(new_datum, increased_value)],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test close_rejects_missing_owner_signature() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(2_000, 2_500),
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test close_rejects_wrong_destination() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(beneficiary_address(), terminal_value())],
    mint: terminal_mint(),
    validity_range: validity_window(2_000, 2_500),
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test fixed_release_rejects_reduced_value() fail {
  let datum = fixed_datum()
  let reduced = assets.merge(
    assets.from_lovelace(49_000_000),
    assets.from_asset(receipt_policy, terminal_receipt_name, 1),
  )
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    outputs: [plain_output(beneficiary_address(), reduced)],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test bearer_release_rejects_two_recovery_tokens_in_inputs() fail {
  let datum = bearer_datum()
  let second_recovery = Input {
    ..recovery_input(),
    output_reference: second_recovery_ref,
  }
  let valid_tx = bearer_release_tx(datum)
  expect [payout_output] = valid_tx.outputs
  let tx = Transaction {
    ..valid_tx,
    inputs: [own_input(datum), recovery_input(), second_recovery],
    outputs: [payout_output, recovery_output(owner_address(), 1)],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test terminal_release_converts_active_receipt() {
  let datum = fixed_datum()
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    outputs: [plain_output(beneficiary_address(), terminal_value())],
    mint: terminal_mint(),
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test finalize_mint_accepts_valid_terminal_conversion() {
  let datum = fixed_datum()
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.FinalizeReceipt,
    receipt_policy,
    fixed_release_tx(datum, beneficiary_address(), 31_000),
  )
}

test finalize_mint_rejects_receipt_from_key_input() fail {
  let datum = fixed_datum()
  let key_input = Input {
    ..own_input(datum),
    output: plain_output(owner_address(), vault_value()),
  }
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    inputs: [key_input],
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.FinalizeReceipt,
    receipt_policy,
    tx,
  )
}

test finalize_mint_rejects_extra_policy_asset() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    mint: assets.merge(
      terminal_mint(),
      assets.from_asset(receipt_policy, unexpected_name, 1),
    ),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.FinalizeReceipt,
    receipt_policy,
    tx,
  )
}

test finalize_mint_rejects_missing_terminal_output() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    outputs: [
      plain_output(beneficiary_address(), assets.from_lovelace(50_000_000)),
    ],
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.FinalizeReceipt,
    receipt_policy,
    tx,
  )
}

test terminal_spend_rejects_duplicate_terminal_outputs() fail {
  let datum = fixed_datum()
  let payout = plain_output(beneficiary_address(), terminal_value())
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    outputs: [payout, payout],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test terminal_receipt_cannot_resurrect_active_state() fail {
  let datum = fixed_datum()
  let resurrected_input = Input {
    ..own_input(datum),
    output: vault_output(datum, terminal_value()),
  }
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    inputs: [resurrected_input],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test mint_accepts_maximum_supported_miss_threshold() {
  let datum = baton.VaultDatum { ..fixed_datum(), misses_to_release: 1_000 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_negative_check_in_period() fail {
  let datum = baton.VaultDatum { ..fixed_datum(), check_in_period_ms: -1 }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    mint_tx(datum),
  )
}

test mint_rejects_missing_inline_datum() fail {
  let datum = fixed_datum()
  let output = Output { ..vault_output(datum, vault_value()), datum: NoDatum }
  let tx = Transaction { ..mint_tx(datum), outputs: [output] }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_hashed_datum() fail {
  let datum = fixed_datum()
  let output = Output {
    ..vault_output(datum, vault_value()),
    datum: DatumHash(
      #"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    ),
  }
  let tx = Transaction { ..mint_tx(datum), outputs: [output] }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_receipt_at_wrong_script() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..mint_tx(datum),
    outputs: [
      Output {
        ..vault_output(datum, vault_value()),
        address: beneficiary_address(),
      },
    ],
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_duplicate_receipt_outputs() fail {
  let datum = fixed_datum()
  let output = vault_output(datum, vault_value())
  let tx = Transaction { ..mint_tx(datum), outputs: [output, output] }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test mint_rejects_two_receipt_tokens() fail {
  let datum = fixed_datum()
  let doubled = assets.merge(
    assets.from_lovelace(50_000_000),
    assets.from_asset(receipt_policy, receipt_name, 2),
  )
  let tx = Transaction {
    ..mint_tx(datum),
    outputs: [vault_output(datum, doubled)],
    mint: assets.from_asset(receipt_policy, receipt_name, 2),
  }
  baton.baton.mint(
    seed_ref,
    receipt_name,
    baton.MintReceipt,
    receipt_policy,
    tx,
  )
}

test pulse_rejects_changed_liveness_key() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    liveness: beneficiary,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_changed_release_policy() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    release_policy: baton.BearerRecovery {
      policy_id: recovery_policy,
      asset_name: recovery_name,
    },
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_changed_payload_commitment() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    payload_commitment: Some(#"00"),
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_changed_schema_version() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    schema_version: 2,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_changed_script_address() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let output = Output {
    ..vault_output(new_datum, vault_value()),
    address: beneficiary_address(),
  }
  let tx = Transaction { ..pulse_tx(old_datum, new_datum), outputs: [output] }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_changed_reference_script() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let output = Output {
    ..vault_output(new_datum, vault_value()),
    reference_script: Some(receipt_policy),
  }
  let tx = Transaction { ..pulse_tx(old_datum, new_datum), outputs: [output] }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_missing_output_datum() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let output = Output {
    ..vault_output(new_datum, vault_value()),
    datum: NoDatum,
  }
  let tx = Transaction { ..pulse_tx(old_datum, new_datum), outputs: [output] }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_rejects_redeemer_datum_timestamp_mismatch() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 1_999 },
    own_ref,
    pulse_tx(old_datum, new_datum),
  )
}

test pulse_rejects_unbounded_validity_range() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    validity_range: Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(1_500),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: PositiveInfinity,
        is_inclusive: True,
      },
    },
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test pulse_accepts_unrelated_transaction_parts() {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let tx = Transaction {
    ..pulse_tx(old_datum, new_datum),
    inputs: [own_input(old_datum), recovery_input()],
    outputs: [
      plain_output(owner_address(), assets.from_lovelace(2_000_000)),
      vault_output(new_datum, vault_value()),
    ],
    mint: assets.from_asset(recovery_policy, "UNRELATED", 1),
    extra_signatories: [liveness, beneficiary],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(old_datum),
    baton.Pulse { new_check_in_at_ms: 2_000 },
    own_ref,
    tx,
  )
}

test spend_rejects_missing_input_datum() fail {
  let datum = fixed_datum()
  baton.baton.spend(
    seed_ref,
    receipt_name,
    None,
    baton.Close,
    own_ref,
    fixed_release_tx(datum, owner_address(), 2_000),
  )
}

test spend_rejects_receipt_missing_from_own_input() fail {
  let datum = fixed_datum()
  let bad_input = Input {
    ..own_input(datum),
    output: vault_output(datum, assets.from_lovelace(50_000_000)),
  }
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    inputs: [bad_input],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test spend_rejects_receipt_remint() fail {
  let datum = fixed_datum()
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    mint: assets.from_asset(receipt_policy, receipt_name, 1),
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test close_rejects_value_added_to_payout() fail {
  let datum = fixed_datum()
  let increased = assets.merge(
    assets.from_lovelace(51_000_000),
    assets.from_asset(receipt_policy, terminal_receipt_name, 1),
  )
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(datum)],
    outputs: [plain_output(owner_address(), increased)],
    mint: terminal_mint(),
    validity_range: validity_window(2_000, 2_500),
    extra_signatories: [owner],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Close,
    own_ref,
    tx,
  )
}

test fixed_release_rejects_mismatched_redeemer_address() fail {
  let datum = fixed_datum()
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: owner_address() },
    own_ref,
    fixed_release_tx(datum, beneficiary_address(), 31_000),
  )
}

test fixed_release_accepts_exact_inline_payout_datum() {
  let payout_data: Data = 42
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.FixedDestination {
      address: beneficiary_address(),
      datum: baton.InlinePayoutDatum(payout_data),
    },
  }
  let output = Output {
    ..plain_output(beneficiary_address(), terminal_value()),
    datum: InlineDatum(payout_data),
  }
  let tx = Transaction {
    ..fixed_release_tx(datum, beneficiary_address(), 31_000),
    outputs: [output],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test fixed_release_rejects_wrong_payout_datum() fail {
  let payout_data: Data = 42
  let datum = baton.VaultDatum {
    ..fixed_datum(),
    release_policy: baton.FixedDestination {
      address: beneficiary_address(),
      datum: baton.InlinePayoutDatum(payout_data),
    },
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    fixed_release_tx(datum, beneficiary_address(), 31_000),
  )
}

test bearer_release_rejects_recovery_token_missing_from_payout() fail {
  let datum = bearer_datum()
  let tx = Transaction {
    ..bearer_release_tx(datum),
    outputs: [plain_output(beneficiary_address(), terminal_value())],
  }
  baton.baton.spend(
    seed_ref,
    receipt_name,
    Some(datum),
    baton.Release { payout_address: beneficiary_address() },
    own_ref,
    tx,
  )
}

test two_vaults_can_pulse_in_one_transaction_without_state_reuse() {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(old_datum), second_own_input(old_datum)],
    outputs: [
      vault_output(new_datum, vault_value()),
      second_vault_output(new_datum, second_vault_value()),
    ],
    validity_range: validity_window(1_500, 2_000),
    extra_signatories: [liveness],
  }
  and {
    baton.baton.spend(
      seed_ref,
      receipt_name,
      Some(old_datum),
      baton.Pulse { new_check_in_at_ms: 2_000 },
      own_ref,
      tx,
    ),
    baton.baton.spend(
      seed_ref,
      second_receipt_name,
      Some(old_datum),
      baton.Pulse { new_check_in_at_ms: 2_000 },
      second_own_ref,
      tx,
    ),
  }
}

test two_vaults_cannot_reuse_one_combined_state_output() fail {
  let old_datum = fixed_datum()
  let new_datum = baton.VaultDatum {
    ..old_datum,
    last_check_in_at_ms: 2_000,
    sequence: 1,
  }
  let combined_value = assets.merge(vault_value(), second_vault_value())
  let tx = Transaction {
    ..transaction.placeholder,
    inputs: [own_input(old_datum), second_own_input(old_datum)],
    outputs: [vault_output(new_datum, combined_value)],
    validity_range: validity_window(1_500, 2_000),
    extra_signatories: [liveness],
  }
  and {
    baton.baton.spend(
      seed_ref,
      receipt_name,
      Some(old_datum),
      baton.Pulse { new_check_in_at_ms: 2_000 },
      own_ref,
      tx,
    ),
    baton.baton.spend(
      seed_ref,
      second_receipt_name,
      Some(old_datum),
      baton.Pulse { new_check_in_at_ms: 2_000 },
      second_own_ref,
      tx,
    ),
  }
}
