# Threat Model

## Protected properties

- Protected value cannot leave early except through an owner-authorized close.
- The liveness key can renew time but cannot redirect or remove value.
- A release cannot occur before the final release boundary.
- A terminal release follows exactly the immutable release policy.
- One payment cannot satisfy two vault spends.
- The canonical state cannot be forged, duplicated, or ambiguously continued.
- On-chain state never claims to provide information confidentiality.

## Trust assumptions

The design trusts Cardano ledger validation, transaction signatures, hash
security, and the semantics of the compiled validator. It does not trust the UI,
transaction builder, indexer, relayer, executor, recipient, or watchtower to
construct an honest transaction; the on-chain validator must reject dishonest
transactions from all of them.

The user must trust that Cardano remains available long enough to submit a pulse
before the configured missed-check-in threshold is reached. The contract cannot
compensate for a chain halt or broad wallet/provider outage.

## Adversaries

- An arbitrary party who can inspect all on-chain state and pending transactions.
- A malicious transaction builder or relayer.
- A thief holding only the liveness key.
- A thief holding the owner key.
- A thief holding the bearer recovery token.
- A recipient attempting early or excessive withdrawal.
- Multiple vault users whose inputs are combined in one transaction.
- A party sending unsolicited UTxOs or tokens to the script address.

## Threats and mitigations

| Threat | Mitigation | Residual risk |
|---|---|---|
| Forged state datum | Unique one-shot vault receipt NFT identifies canonical state | One-shot policy or parameterization bugs must be audited |
| Two continuing states | Require exactly one output containing the receipt NFT | None expected if token uniqueness holds |
| Completed plan is made to look active again | Terminal action burns the active receipt and mints a differently named completion receipt; only the active receipt identifies state | Indexers must use the active unit, not merely the script address or policy ID |
| Pulse siphons assets | Continuing value must equal own-input value exactly | Pulse fee needs an external input |
| Pulse changes recipients or timing rules | Preserve every datum field except due time and sequence | Serialization equality must be tested carefully |
| Rapid pulses stack years | New due time is anchored to a short validity window, not old due time | Future pre-signed transactions cannot be distinguished from live intent |
| Early release | Require a trusted lower validity bound after final release | Boundary inclusivity mistakes are a critical test target |
| Owner closes after release | Owner path requires a validity upper bound before final release | Owner who reaches the configured miss threshold loses privileged recovery |
| One output unlocks multiple vaults | Each vault policy uniquely tags its own completion payout | Multi-input adversarial tests remain mandatory |
| Bearer token is merely observed, not controlled | Require it in a spent non-vault input and bind it to the payout output | A stolen token conveys the recovery right by design |
| Recovery token is duplicated | Bearer creation mints exactly one fixed-name token under the seed-bound one-shot policy and rejects every other mint shape | The token remains a transferable bearer credential; theft transfers the recovery right |
| Bearer release is front-run | Copied transaction preserves the signed bearer input and intended payout | A compromised bearer wallet can redirect funds |
| Unsolicited script deposits confuse indexer | Only the active-receipt UTxO is canonical; a completion receipt at the script remains terminal | Unsolicited funds may be permanently stuck |
| Datum or asset bundle becomes too large | The optional payload commitment is fixed to one 32-byte SHA-256 digest; benchmark maximum value sizes | Protocol parameter changes can alter limits/costs |
| Transaction builder lies | On-chain checks enforce all value, time, signer, and output conditions | UI can still mislead before initial creation; manifest review is required |
| Watchtower disappears | Any party can submit fixed releases; users can configure multiple monitors | A pulse still requires the liveness credential |
| Chain/indexer outage near deadline | Multiple allowed misses, redundant providers, local manifest | A sufficiently long chain halt remains fatal to liveness |
| Private information leaks | Store only encrypted bytes off-chain and a commitment on-chain | Later key-release network adds separate trust assumptions |

## Key compromise consequences

### Liveness key stolen

The thief cannot take assets or change the policy, but can keep renewing the vault
and delay release indefinitely. This is an unavoidable consequence of treating
that credential as proof of life. Rotation or recovery would require the owner
key and a carefully specified transition; the narrow first release instead uses
owner close-and-recreate.

### Owner key stolen

Before final expiry, the thief can close the vault and take the assets. No
validator can distinguish the rightful owner from a thief producing a valid
signature. Hardware storage or a multisignature owner credential is recommended.

### Recovery token stolen or lost

In bearer mode, the thief acquires the post-expiry recovery right. That is the
meaning of bearer ownership. If the token is lost and the plan reaches expiry,
the protected assets can become permanently inaccessible. The token should be
secured like a cold private key or held by a multisignature/script policy.

## Fundamental limitations

### A transaction is not proof that a human is currently alive

The protocol proves only that an authorized transaction was included. A user may
pre-sign a future transaction or give an automated agent authority to pulse.
Preventing that requires a fresh external challenge, trusted hardware, an oracle,
or another assumption outside the pure validator.

### The contract cannot execute itself

After expiry, someone still must construct, fund, and submit the release
transaction. Fixed mode makes this permissionless; a monitoring service and
optional future bounty improve reliability but do not change the validator's
passive nature.

### Public chains do not keep secrets

Encrypting a payload protects it only while its key remains unavailable. A smart
contract cannot privately hold a key and later reveal it by itself.

## Out-of-scope risks for the core validator

- Malware or supply-chain attacks in the wallet.
- Loss, censorship, or corruption of encrypted off-chain payload storage.
- Legal validity of inheritance instructions in a user's jurisdiction.
- Tax treatment or sanctions obligations.
- Bugs in downstream distribution scripts or multisignature wallets.
- Social engineering around recovery tokens or fake vault interfaces.
