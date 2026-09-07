# Release checklist

## Completed locally

- [x] Versioned Plutus V3 datum fails closed on unsupported versions.
- [x] Configurable period and 1-1,000 allowed-miss threshold enforced.
- [x] Fixed and beneficiary-free one-shot recovery-token modes implemented.
- [x] 91 deterministic validator tests pass, including terminal-receipt replay,
  malformed commitment, and owner-close validity-window regression cases.
- [x] Four property tests pass across 4,000 generated schedules, exact release
  boundaries, pre-boundary rejections, and multi-check-in terminal sequences.
- [x] Repeated-pulse state sequence and 12 generated schedule boundaries execute
  against the compiled validator in the Cardano emulator.
- [x] 2,000 generated schedule-model cases cover exact pre-boundary, boundary,
  missed-count, and renewal invariants.
- [x] Multi-vault batching succeeds with separate canonical outputs and rejects
  reuse of one combined state output.
- [x] Terminal close/release burns the active receipt, mints the distinct
  completion receipt, and cannot be made active again by redepositing it.
- [x] ADA, NFT, and fungible native-token quantities survive repeated pulses and
  owner close without drift.
- [x] Direct no-interface-fee creation executes and pays the treasury zero.
- [x] Official creation independently verifies its exact vault and 5 ADA fee
  outputs before signing.
- [x] Site lint, type checks, build, route tests, manifest mutation tests,
  security-header tests, and mobile/desktop QA pass.
- [x] Production and development dependency audit reports zero known
  vulnerabilities for the frozen lockfile.
- [x] Reproducible release manifest and source verifier exist.
- [x] Six security-critical contract mutations are all rejected by the frozen
  test suite.
- [x] Mainnet builds require an explicit release acknowledgement.

## Blocking public or Mainnet release

- [x] Real operator Preprod treasury address recorded in release configuration.
- [x] Full Preprod lifecycle transaction IDs recorded using the frozen rc.10
  artifact, including fixed release, bearer release, five check-ins, and owner
  close.
- [x] Bearer recovery token is minted exactly once by the seed-bound plan policy;
  creation rejects missing, duplicate, external, misdirected, or vault-contained
  recovery credentials.
- [ ] Long-running missed-pulse and provider-outage soak completed.
- [ ] Independent Cardano smart-contract review completed with no unresolved
  critical or high findings.
- [ ] Legal review completed for the actual operator, fee flow, marketing, terms,
  jurisdictions, and privacy practices.
- [ ] Public security contact/private advisory channel activated.
- [ ] Public testnet challenge or bug bounty completed.
- [ ] Clean-machine reproducible build confirmed.
- [ ] Conservative Mainnet value cap and incident owner assigned.
- [ ] Canonical GitHub organization/repository selected and published.

No unchecked item may be implied complete by marketing or UI copy.
