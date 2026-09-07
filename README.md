# Baton for Cardano

[![Contract CI](https://github.com/chaplinkyle/baton-cardano/actions/workflows/ci.yml/badge.svg)](https://github.com/chaplinkyle/baton-cardano/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-6e67b1.svg)](LICENSE)
[![Network: Preprod](https://img.shields.io/badge/network-Preprod-c79b58.svg)](docs/RELEASE_CHECKLIST.md)

Baton is a non-custodial Cardano handoff protocol. An owner locks ADA, native
tokens, or NFTs in a Plutus V3 contract and keeps the plan active with periodic
check-ins. When the configured number of check-ins has been missed, the complete
protected value becomes releasable under the immutable policy selected at
creation.

> **Preprod only.** This candidate has not completed an independent audit and
> is not approved for Mainnet or valuable assets.

## Protocol

```text
release time = last confirmed check-in + check-in period × allowed misses
```

- **Fixed destination:** the complete protected value can only be released to
  the address committed at creation.
- **Recovery token:** no beneficiary is named in advance. The holder of the
  unique `BATON_RECOVERY` token selects the receiving address after expiry.
- **Owner close:** before expiry, the owner may close the plan and recover the
  complete protected value.
- **Check-in:** the separate liveness key advances the state while preserving
  the exact value, policy, and owner configuration.

The validator charges no protocol fee and has no administrator, upgrade,
pause, or withdrawal key. Interfaces may independently charge for services;
those fees are not required by this contract.

## Frozen candidate

| Item | Value |
|---|---|
| Release | `0.1.0-rc.10` |
| Network | Cardano Preprod |
| Language | Aiken / Plutus V3 |
| Aiken | `v1.1.23` |
| Validator hash | `199955b94b93bd11624d5e7c0a201ae11e32270377df63b5317f6fb1` |
| Blueprint SHA-256 | `b0809a00186e40ffca51511dbd81086d642be7149b6d1852fe127fc1822d22fc` |

The complete source inventory and hashes are recorded in
[`release/release-manifest.json`](release/release-manifest.json).

## Build and test

Install [Aiken](https://aiken-lang.org/installation-instructions) `v1.1.23` and
Node.js 22 or newer, then run:

```bash
npm test
npm run test:mutations
npm run build
npm run release:verify
```

The frozen suite contains 91 deterministic validator tests, four property tests
with 4,000 generated cases, and six mutation tests that deliberately weaken
security-critical rules and require the suite to fail.

## Evidence and review

- [Protocol specification](docs/PROTOCOL_SPEC.md)
- [Threat model](docs/THREAT_MODEL.md)
- [Test report](docs/CONTRACT_TEST_REPORT.md)
- [Independent audit scope](docs/AUDIT_SCOPE.md)
- [Public Preprod evidence](evidence/preprod-rc10.json)
- [Release gates](docs/RELEASE_CHECKLIST.md)

The companion Eternl interface lives in
[`chaplinkyle/baton-web`](https://github.com/chaplinkyle/baton-web). It is a
separate implementation and is not required to use the protocol.

## License

[Apache-2.0](LICENSE). This is software, not legal, financial,
estate-planning, or custodial advice, and it is provided without warranty.
