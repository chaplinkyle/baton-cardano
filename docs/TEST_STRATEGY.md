# Test and Release Strategy

No responsible team can prove a financial smart contract is “100% perfect.” The
release target is narrower and auditable: every specified transition is tested,
all known invalid mutations are rejected, execution costs stay within measured
margins, independent reviewers find no unresolved critical issue, and mainnet
exposure begins with strict limits.

## Verification layers

### 1. Executable model

Build a small pure state-transition model before the production validator. The
model accepts a state, action, authorization set, transaction time range, and
value movement, then returns either the next state or rejection.

The production validator and the model must agree across generated transactions.

### 2. Aiken unit tests

Test every action at minimum with:

- the normal valid transaction;
- each required field missing;
- each signature missing or replaced;
- each time bound before, at, and after its boundary;
- each protected datum field changed independently;
- one asset unit removed, added, or redirected;
- zero, one, and multiple receipt-bearing outputs;
- malformed, hashed, missing, and unsupported datums;
- extra unrelated inputs, outputs, signers, minting, and withdrawals;
- multiple vault inputs combined into one transaction.

### 3. Property-based tests

Generate datums, values, credentials, intervals, outputs, and transaction shapes.
At minimum, prove empirically over large generated samples:

1. A valid pulse never decreases any protected asset.
2. A valid pulse changes only due time and sequence.
3. A transaction accepted before final expiry is never accepted as a release.
4. A transaction accepted after final expiry is never accepted as pulse or close.
5. A party with only the liveness key cannot produce a terminal payout.
6. A party with no owner key cannot close early.
7. Every accepted terminal transaction burns one active receipt, mints one
   distinct completion receipt, and places it with all required protected value
   under the selected release rule.
8. Reordering unrelated inputs and outputs does not change a valid result.
9. Duplicating candidate payout outputs cannot make an invalid transaction valid.
10. Combining multiple vault inputs cannot reuse one payout.
11. For every valid period and miss threshold, release is rejected immediately
    before `last_check_in + period * misses` and allowed at the boundary.
12. Every accepted pulse resets the elapsed miss count to zero without changing
    the configured period or miss threshold.

Fuzzer label distributions must be inspected so success is not caused by a
generator that rarely reaches important branches.

### 4. State-machine tests

Generate long sequences containing creation, early pulse, late pulse, repeated
pulse, close, expiry, release, duplicate release, and malformed actions. Compare
the abstract model to validator execution after every transition.

Important sequence properties:

- exactly one canonical state exists while active;
- no active receipt or canonical state exists after a terminal transition;
- returning a completion receipt to the validator with a plausible datum cannot
  resurrect active state;
- a consumed vault can never pulse or release again;
- immediate repeated pulses do not accumulate periods;
- liveness continues across many valid renewals without datum drift;
- expiry is determined only by the latest confirmed canonical state.

### 5. Adversarial mutation suite

Begin with known-valid transaction fixtures, mutate one property at a time, and
require rejection. Mutations include signatures, credentials, token quantities,
asset names, policy IDs, timestamps, interval inclusivity, output addresses,
datum constructors, sequence values, state-token location, payout tagging, and
mint fields.

Every bug found during development or review becomes a permanent regression test.

### 6. Cost benchmarks

Measure CPU, memory, script size, transaction size, and minimum ADA for:

- each release policy;
- smallest and largest supported asset bundles;
- extra unrelated transaction inputs and outputs;
- worst-case credential and datum forms.

Supported limits will be set below protocol maxima with an explicit safety
margin. A protocol-parameter change triggers a benchmark rerun before a new
release.

### 7. Off-chain integration tests

The transaction builder must be tested against a real compiled blueprint for:

- creation and manifest export;
- pulse with external fee input;
- owner close;
- fixed release by an unrelated executor;
- bearer release from several wallet/script arrangements;
- all boundary and insufficient-minimum-ADA failures;
- provider/indexer disagreement and stale UTxO handling;
- wallet rejection, cancellation, and resubmission.

The website additionally must prove that:

- it requests only transaction signatures and never asks for a seed phrase or
  private key;
- the final transaction exactly matches the values, deadlines, release policy,
  validator hash, fee address, and fee amount displayed on the review screen;
- the setup fee is paid only when the complete vault-creation transaction is
  accepted atomically;
- changing the fee output, vault output, receipt NFT, or compiled validator hash
  causes local verification to fail before wallet signing;
- no setup fee is added to pulse, close, or release transactions;
- a user can reproduce the same no-protocol-fee contract interaction using the
  published command-line or library tooling;
- network fees and minimum ADA are never labeled as operator revenue;
- every irreversible risk disclosure appears in the action flow, not only in a
  linked legal document; and
- analytics, if introduced, do not collect wallet addresses or transaction data
  without a separately documented and consented purpose.

Eternl/CIP-30 tests must cover:

- provider absent, disabled, refused, stale, and wrong-network states;
- account changes during review and before signing;
- user rejection of connection, signing, and submission;
- `signTx` returning incomplete, malformed, or unexpected witnesses;
- successful extension and dApp-browser connections;
- pulse construction with several wallet UTxO and change arrangements;
- safe collateral return and proof that successful pulses do not consume
  collateral;
- an exact zero delta for every protected vault asset;
- exactly one calculated Cardano fee and zero site fee on every pulse;
- a 5 ADA site fee only on official-site creation transactions; and
- no reset miss count displayed until the new canonical UTxO is confirmed.

The builder must never treat an off-chain preflight as security. The validator is
the authority.

### 8. Network testing

Run in this order:

1. local/emulator tests with controlled time;
2. Cardano preview testnet integration;
3. preprod rehearsal using the exact release artifact;
4. a long-running soak with scheduled pulses, missed pulses, and independent
   release executors;
5. reproducible rebuild and hash comparison on a clean machine.

### 9. Independent review

Before public mainnet use:

- freeze the specification and validator code;
- obtain an independent Cardano smart-contract security review following the
  CIP-52 audit guidelines;
- resolve every critical/high finding and retest all fixes;
- publish the report, compiler version, dependency commits, blueprint hash, test
  commands, test vectors, and known limitations;
- run a public testnet challenge or bug bounty.

## Initial release gates

Mainnet release is blocked until all are true:

- no TODO, ignored, expected-to-fail unexpectedly, or skipped security tests;
- every decision in the protocol specification is implemented or explicitly
  removed from scope;
- all deterministic unit and integration tests pass from a clean checkout;
- property and state-machine suites complete at their frozen sample counts;
- all benchmarked paths have the agreed execution and size margin;
- independent review has no unresolved critical or high-severity issue;
- testnet artifacts rebuild to the exact expected hashes;
- operational runbooks cover lost keys, missed pulses, provider outages, and
  emergency disclosure;
- the mainnet pilot has a conservative per-vault value cap and clear experimental
  labeling.

## Required public artifacts

- Human-readable protocol specification.
- Threat model and known limitations.
- Aiken source and pinned dependency/compiler versions.
- Compiled Plutus blueprint and reproducible build instructions.
- Unit, property, state-machine, mutation, integration, and benchmark results.
- Off-chain builder source.
- Testnet transaction IDs for every happy path.
- Independent review report and remediation notes.
- Mainnet validator hash verification instructions.
- The exact site fee, fee address, client release hash, and transaction-verifier
  instructions for each published interface release.
