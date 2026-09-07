# Direct integration

Baton has no protocol or operator-fee requirement. Any conforming transaction
builder may interact with the compiled Plutus V3 validator in `plutus.json`.

An integration must apply the validator parameters, derive the policy ID and
script address, mint the exact receipt shape, construct the canonical inline
datum, and preserve or release the complete protected value according to the
protocol specification.

Before signing, independently verify:

- the seed UTxO is consumed exactly once;
- the applied policy ID and validator address;
- the active, completion, and optional recovery asset names;
- the complete datum and release policy;
- the exact protected value and minimum ADA;
- every fee output introduced by the integration; and
- the selected Cardano network.

The reference implementation is maintained separately in
[`chaplinkyle/baton-web`](https://github.com/chaplinkyle/baton-web). Its
off-chain builders are useful integration examples but are not part of the
on-chain trust boundary.
