# Contract test report: 0.1.0-rc.10

Date: 2026-09-07

Network target: Cardano Preprod

Compiler: Aiken `v1.1.23+8949565`

Property seed: `20260906`

## Artifact under test

- Raw validator hash: `199955b94b93bd11624d5e7c0a201ae11e32270377df63b5317f6fb1`
- Blueprint SHA-256: `b0809a00186e40ffca51511dbd81086d642be7149b6d1852fe127fc1822d22fc`
- Compiled Plutus V3 code: 4,505 bytes
- Production blueprint: `plutus.json`
- Interface artifact verified against the blueprint SHA-256

## Results

The frozen contract command is:

```text
aiken check --deny --seed 20260906 --max-success 1000
```

It completed with 95 of 95 tests passing and no warnings:

- 91 deterministic valid-path and adversarial mutation tests;
- 4 property tests;
- 1,000 generated cases per property, or 4,000 generated cases total;
- generated check-in periods, allowed-miss thresholds, timestamps, exact
  release boundaries, one-millisecond-early rejections, and 1-20 transition
  check-in sequences ending in a valid release.

The site suite also passed:

- the production blueprint equality check;
- all route, branding, fee, manifest, and security-header tests;
- TypeScript and ESLint checks;
- a Lucid Cardano emulator lifecycle covering official and direct creation,
  repeated check-in, owner close, fixed release, bearer release, and terminal
  replay rejection.

The mutation gate deliberately weakened six security-critical rules. The suite
killed all six mutations, including removal of the one-shot seed, check-in
signature, release boundary, exact recovery-token count, value preservation,
and owner/check-in key separation. This gate runs in CI with
`npm run contract:mutations`.

## Public Preprod lifecycle run: rc.10

An isolated set of software wallets completed all three rc.10 lifecycle paths
on public Cardano Preprod on 2026-09-07. The run used only faucet test ADA and
required no Eternl approvals. Its machine-readable record is
`artifacts/preprod-automation/run-2026-09-07T13-50-53.770Z.json`.
This raw automation record is intentionally separate from the final reviewed
evidence schema, which also requires a clean-machine rebuild and named reviewer.

| Lifecycle | Creation | Terminal transaction | Result |
|---|---|---|---|
| Fixed beneficiary release | [`2b1dfd2...efc98`](https://preprod.cardanoscan.io/transaction/2b1dfd27b89242b29aef603d232633f9d594ad9e6f5d15970cf3251bb08efc98) | [`e04b174...b4a8`](https://preprod.cardanoscan.io/transaction/e04b174bbd20b2198d0add07068b614ea2f2616f7f777fd0b0e22110e167b4a8) | Exact 15 tADA payload paid to the fixed beneficiary |
| Bearer recovery-token release | [`51aa2d7...7af4`](https://preprod.cardanoscan.io/transaction/51aa2d7f0a3975e4f64f68965963d419e3fc5f170ea78bd8df7c9ff7d7837af4) | [`0f82747...ab89`](https://preprod.cardanoscan.io/transaction/0f82747d0a66256ede13c35263d78a0c406ea129b9b41d1890d16a653e31ab89) | Non-holder rejected; holder received 15 tADA and the recovery token |
| Five check-ins then owner close | [`5ac5cee...5b80`](https://preprod.cardanoscan.io/transaction/5ac5cee8ef48845c86fb63b9f349f8ef18adef4175b544a4561e2d4b796d5b80) | [`7aba10c...b69b`](https://preprod.cardanoscan.io/transaction/7aba10c461f6886568a577fff89fba6e3e9b9b235bdb7856709439d968c7b69b) | Sequences 1-5 confirmed; exact payload returned to owner |

The run confirmed that new plans mint `BATON`; bearer plans additionally mint
`BATON_RECOVERY`; and every terminal path burns `BATON` and mints
`BATON_COMPLETE`. Each creation charged exactly 5 tADA through the interface
path. Check-ins, owner close, and releases charged zero additional interface
fees. Network transaction fees ranged from 0.406630 to 0.438420 tADA.

## Prior public Preprod lifecycle run

An isolated set of software wallets completed all three rc.9 lifecycles on
public Cardano Preprod on 2026-09-06. This proves the legacy contract path but
does not substitute for a fresh rc.10 rehearsal. The run used only faucet test
ADA and required no Eternl approvals. Its machine-readable record is
`artifacts/preprod-automation/run-2026-09-06T22-27-13.571Z.json`.

| Lifecycle | Creation | Terminal transaction | Result |
|---|---|---|---|
| Fixed beneficiary release | [`0e1ae7f…c153f`](https://preprod.cardanoscan.io/transaction/0e1ae7f05de4f714e739a9693125ee1284307dbc668cd4d69ebc4fef244c153f) | [`3ae93e3…a9861b`](https://preprod.cardanoscan.io/transaction/3ae93e38e886be246fd6b607a046e33a0ed55f91c646e453c8661bfaa9a9861b) | Exact 15 tADA payload paid to the fixed beneficiary |
| Bearer recovery-token release | [`b7c6ed9…f0558f`](https://preprod.cardanoscan.io/transaction/b7c6ed9767395877a075042fcfb7b4ef608d56e16b693ab8a9d2e55a73f0558f) | [`adf93e0…dd348`](https://preprod.cardanoscan.io/transaction/adf93e0068d7e4b0a8588e487e9fc345d5591b6c2f6223f9ba909482ba4dd348) | Non-holder rejected; holder received 15 tADA and the recovery token |
| Five check-ins then owner close | [`2fb3b94…f6118`](https://preprod.cardanoscan.io/transaction/2fb3b94e92e49c4d96808ab57b986a930bdb0943b665437a0780459998ef6118) | [`9b89c36…9be72`](https://preprod.cardanoscan.io/transaction/9b89c36f660e54b25f65e578126b79eec0780c458962f38baffba37f1879be72) | Sequences 1-5 confirmed; exact payload returned to owner |

The successful transactions measured 5,096-5,403 bytes and
0.408920-0.441971 tADA in network fees. Each creation charged exactly 5 tADA
through the interface path. All five check-ins and both terminal paths charged
zero additional interface fees.

## Security corrections in this candidate

### One-shot bearer recovery

Bearer plans now mint exactly one dedicated `BATON_RECOVERY` token under
the same seed-bound policy as the active receipt. Creation sends it to the owner
outside the vault and rejects missing, duplicate, extra, externally defined,
misdirected, or vault-contained recovery tokens. This moves uniqueness from an
unverifiable assumption about an arbitrary native asset into the on-chain
creation policy.

### Owner-close validity window

The close branch previously assigned the result of `finite_bounded_window` to an
unused variable. Aiken correctly warned that unused `let` bindings are removed,
so the intended check was not enforced on-chain. The branch now consumes the
validated finite bounds, and regression tests reject both an unbounded lower
bound and a validity window wider than 15 minutes.

The owner signature and owner-only payout still prevented third-party theft in
the earlier candidate, but stale or unexpectedly broad owner-close
authorization violated the protocol specification. No rc.7 mainnet deployment
was authorized.

### Terminal-name configuration locks

Creation now rejects an active receipt parameter that equals the completion
receipt name. Bearer creation also rejects either protocol receipt as its
recovery credential. These configurations could not redirect or steal assets,
but direct users could previously create plans with no possible terminal path.

### Payload commitment size

Creation now accepts either no payload commitment or exactly one 32-byte digest.
This makes the validator enforce the same SHA-256 format as the Baton interface
and prevents direct users from creating unexpectedly large state datums.

## Representative script evaluation units

These are fixture-level Aiken evaluator measurements, not final network
transaction budgets. Terminal Cardano transactions execute both the spend and
finalize-mint scripts.

| Script path | Memory | CPU |
|---|---:|---:|
| Create receipt with SHA-256 commitment | 322,429 | 103,108,978 |
| Check in | 351,210 | 117,219,908 |
| Owner close spend | 389,762 | 120,603,227 |
| Fixed release spend | 377,445 | 118,412,668 |
| Bearer release spend | 597,806 | 181,737,071 |
| Finalize receipt mint | 281,806 | 81,698,282 |
| Owner close plus finalize mint | 671,568 | 202,301,509 |
| Fixed release plus finalize mint | 659,251 | 200,110,950 |
| Bearer release plus finalize mint | 879,612 | 263,435,353 |

## Remaining release gates

This report does not approve mainnet use. Still required are a long-running
soak, a clean-machine rebuild, independent Cardano contract review, public
security testing, legal review, and a capped mainnet pilot.
