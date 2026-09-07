# Protocol Specification

This document describes the implemented version-one validator. Any semantic
change requires a new compiled hash, updated test vectors, and explicit release
notes.

## State

```text
VaultDatum {
  schema_version: Int,
  owner: VerificationKeyHash,
  liveness: VerificationKeyHash,
  check_in_period_ms: Int,
  misses_to_release: Int,
  last_check_in_at_ms: Int,
  release_policy: ReleasePolicy,
  sequence: Int,
  payload_commitment: Option<ByteArray>
}

ReleasePolicy =
  FixedDestination { address: Address, datum: NoDatum | InlineDatum(Data) }
  | BearerRecovery { recovery_asset: AssetClass }

Action =
  Pulse { new_check_in_at_ms: Int }
  | Close
  | Release { payout_address: Address }
```

Derived values are not stored twice:

```text
next_check_in_at_ms = last_check_in_at_ms + check_in_period_ms
release_at_ms =
  last_check_in_at_ms + (check_in_period_ms * misses_to_release)
```

`misses_to_release` is an integer of at least one. The site can display the
elapsed miss count, but the validator needs only the final release boundary.
The vault identity is not duplicated in the datum. While active, it is the
one-shot `BATON` receipt asset parameterized by the creation seed UTxO and
receipt asset name. A terminal transition atomically burns that active receipt
and mints the distinct `BATON_COMPLETE` completion receipt under the same
unique policy. Bearer creation also mints exactly one `BATON_RECOVERY`
token under that policy and sends it to the owner's payment credential outside
the canonical vault output.

## Global invariants

Every successful spend of the canonical vault UTxO must satisfy all applicable
invariants below.

1. The own input contains exactly one configured vault receipt NFT.
2. The datum is present and decodes to the supported version.
3. The transaction validity range has the finite bound required by its action.
4. Owner and liveness credentials are different at creation.
5. The period is positive and `misses_to_release` is between 1 and 1,000.
6. A pulse mints or burns no asset under the vault policy and creates exactly
   one output containing the active receipt NFT.
7. A close or release burns exactly one active receipt, mints exactly one
   completion receipt, mints no other asset under the vault policy, and creates
   exactly one output containing the completion receipt.
8. An active input can never contain the completion receipt.
9. An optional payload commitment is exactly one 32-byte SHA-256 digest.
10. Unknown actions, malformed datums, unsupported credentials, and unsupported
   output-datum forms fail closed.
11. Bearer creation mints exactly one active receipt and one recovery token;
    fixed creation mints exactly one active receipt and no recovery token.

## Pulse transition

A pulse is valid only when all of the following hold:

1. The liveness credential authorizes the transaction.
2. The transaction's upper validity bound is strictly before the old final
   release boundary.
3. Both validity bounds are finite and their width is at most the configured
   maximum.
4. `new_check_in_at_ms` equals the transaction's upper validity bound.
5. The transaction creates exactly one output at the same validator address that
   contains exactly one vault receipt NFT.
6. The continuing output value equals the own input value exactly. Fees come from
   external wallet inputs, never from protected value.
7. The continuing datum is byte-for-byte semantically identical except that
   `last_check_in_at_ms` becomes the exact new anchor and `sequence` increments
   by one.
8. The release policy, owner, liveness credential, period, miss threshold,
   schema version, receipt NFT, and payload commitment do not change.

The pulse transaction is signed by the configured liveness credential through
the user's wallet. It includes an external wallet input for the Cardano fee and
appropriate Plutus collateral. On successful validation the collateral is not
consumed, wallet change returns to the wallet, and the protected vault value is
recreated exactly. A standalone off-chain message signature cannot satisfy this
transition because no new canonical state UTxO would be created.

Anchoring renewal to a short current validity window prevents rapid repeated
pulses from accumulating future years. It cannot prevent a holder from preparing
future transactions in advance; this limitation is documented in the threat
model.

## Owner close transition

A close is valid only when:

1. the owner credential authorizes the transaction;
2. the transaction's upper validity bound is strictly before the final release
   boundary;
3. the transaction atomically replaces the active receipt NFT with the distinct
   completion receipt NFT;
4. exactly one terminal owner output contains the completion receipt NFT and
   every other asset from the own-input value;
5. there is no continuing active vault output.

After the final boundary, the owner cannot race a close through the privileged
path. The configured missed-check-in windows are the owner's recovery period.

## Fixed-destination release

A fixed release is valid only when:

1. the transaction's lower validity bound is at or after the final release
   boundary;
2. no owner, liveness, beneficiary, or executor signature is required by the
   vault validator;
3. the redeemer payout address equals the configured destination;
4. the transaction atomically replaces the active receipt NFT with the distinct
   completion receipt NFT;
5. exactly one output at the configured destination contains the completion
   receipt NFT and every other asset from the own-input value;
6. any required destination datum matches the immutable commitment;
7. there is no continuing active vault output.

This makes execution permissionless while keeping receipt deterministic.

## Bearer release

A bearer release is valid only when:

1. the transaction's lower validity bound is at or after the final release
   boundary;
2. exactly one configured one-shot recovery token occurs in non-vault transaction inputs;
3. the transaction atomically replaces the active receipt NFT with the distinct
   completion receipt NFT;
4. exactly one output contains both that recovery token and the completion receipt
   NFT;
5. that same output contains every other own-input asset plus the recovery token,
   asset by asset;
6. the recovery token is not minted by the release transaction;
7. there is no continuing active vault output.

The payout address is not stored in the datum. Spending the recovery token's input
provides the bearer authorization under normal ledger rules. The output binds the
recovery token and released value together so a relayer cannot redirect only the
vault assets.

## Creation and one-shot minting

Vault creation uses a one-shot minting policy parameterized by a specific seed
UTxO reference. Fixed mode mints exactly one vault receipt NFT. Bearer mode mints
exactly that receipt plus exactly one `BATON_RECOVERY` token. The receipt
is placed at the validator with the initial datum; the recovery token is sent to
an address with the owner's payment credential and is forbidden from the vault.
Because the seed can be consumed only once, neither token can be minted again.

The same parameterized policy has a separate finalization action. It can burn
the active receipt and mint one completion receipt only while consuming exactly
one active receipt from that policy's own validator. The spending branch and
minting branch both validate the same atomic conversion.

Creation validation must reject:

- duplicate or identical owner and liveness credentials;
- unsupported release policies;
- an active receipt name identical to the completion or recovery receipt name;
- bearer mode naming any policy or asset other than this plan's dedicated
  recovery token;
- a missing, duplicated, misdirected, or vault-contained recovery token;
- invalid periods, miss thresholds, or already-releasable initial state;
- a payload commitment whose length is not exactly 32 bytes;
- a missing or non-inline state datum;
- an initial state output that does not contain exactly one receipt NFT.

## Boundary semantics

The implementation must use tested interval helpers and demonstrate that there
is no timestamp at which both a pre-release transition and a release transition
are valid. Unit tests will cover the exact millisecond before, exact boundary,
and exact millisecond after release.

## Versioning and migration

The first release has no on-chain upgrade authority. Before final expiry, the
owner may close a vault and lock the assets into a newer validator. A datum
schema version is included and must equal one, so unsupported future data fails
explicitly rather than being misinterpreted.
