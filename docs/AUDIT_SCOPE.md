# Independent smart-contract audit scope

Review the exact source set identified by
[`release/release-manifest.json`](../release/release-manifest.json). The compiled
validator under review is [`plutus.json`](../plutus.json). The review should
follow [CIP-52](https://cips.cardano.org/cip/CIP-52).

This scope, the automated evidence, and the public Preprod transactions prepare
an independent review; they do not constitute certification.

## Security-critical files

- `validators/baton.ak`
- `validators/baton_test.ak`
- `aiken.toml` and `aiken.lock`
- `plutus.json`
- `scripts/run-contract-mutations.mjs`
- `docs/PROTOCOL_SPEC.md`
- `docs/THREAT_MODEL.md`

## Required conclusions

The reviewer should independently determine whether:

1. The one-shot active receipt uniquely identifies one canonical plan state and
   cannot be forged, duplicated, or reused.
2. Every close and release atomically burns the active receipt and mints exactly
   one completion receipt; a completion receipt cannot reactivate a plan.
3. A check-in requires the configured liveness key, advances the sequence and
   timestamp exactly once, and preserves the complete protected value.
4. The release boundary is exactly
   `last_check_in + period × allowed_misses`, with no gap or overlap.
5. The owner can close only before expiry and only to the owner address.
6. Fixed release sends the complete protected value only to the immutable
   destination.
7. Recovery-token creation mints exactly one `BATON_RECOVERY` token under the
   seed-bound policy and recovery requires that token in a non-plan input.
8. Multi-plan, duplicate-output, minting, datum, reference-script,
   validity-range, and value-accounting attacks cannot satisfy the validator.
9. Direct interaction requires no protocol or operator fee.
10. Execution units, script size, transaction size, and minimum-ADA behavior
    retain adequate margin under current protocol parameters.
11. Every included security mutation is killed by the frozen test suite.

## Deliverables

The report should identify the reviewer, dates, methodology, threat model,
compiler and dependency versions, artifact hashes, findings and severity,
reproduction steps, remediation status, residual risks, and exact release
manifest reviewed. Critical and high findings must be resolved and retested
before Mainnet use.

An audit is independent only when its reviewer did not author the
implementation.
