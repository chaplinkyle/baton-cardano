# Decision Log

## Accepted design decisions

### Beneficiaries are optional

The datum stores a release policy, not a mandatory beneficiary list. Bearer and
open modes contain no predetermined recipient address.

### Bearer recovery is the recommended no-beneficiary mode

A unique recovery token minted by the plan's seed-bound one-shot policy makes
the right transferable and lets the ledger prove control without publishing a
destination in advance or trusting an unrelated asset's supply.

### The core vault has one terminal destination

Multiple-beneficiary logic belongs in a downstream distribution validator. This
avoids percentage rounding, NFT allocation, minimum-ADA, and double-satisfaction
complexity in the time-critical core.

### Owner and liveness powers are separate

The routine liveness key can only renew. The cold owner credential can close
before final release.

### Expiry is configured as consecutive missed check-ins

The owner selects a check-in frequency and a number of missed check-ins required
for release. The contract derives the final boundary from the latest confirmed
check-in; no transaction is needed to record each miss. Owner close and pulse
paths end before that boundary, and there is no indefinite owner override after
it.

### The validator is immutable

Migration is close-and-recreate before expiry. There is no upgrade key or proxy.

### Active and completion receipts are distinct

The unique active receipt identifies canonical state and prevents spoofing or
ambiguous continuations. A terminal transaction atomically burns it and mints a
different unique completion receipt for the final payout. A moved completion
receipt therefore cannot resurrect a finished plan as apparent active state.

### Information release is a separate module

The core stores at most a commitment. Threshold or time-release encryption needs
a separately specified off-chain system and distinct trust model.

### “Perfect” is not a release claim

The project will publish evidence, test scope, audit findings, hashes, and known
limitations. It will not promise the impossibility of undiscovered bugs.

### The contract is free; the official setup interface is paid

The validator contains no operator fee requirement. The website adds one clearly
disclosed **5 ADA** service-fee output only to transactions it constructs for
new vaults. Direct contract users can bypass the site and its fee.

### The website is non-custodial by construction

The site builds unsigned transactions in the browser. The user's own wallet
signs them. The operator never controls protected assets or keys and has no
contract administration capability. Product copy will call this a setup
interface, not a managed wallet, account, escrow, or contract-management service.

### Legal disclaimers are not treated as exemptions

The site's actual flow must support its claims. U.S. federal, state, sanctions,
consumer-protection, estate, tax, and privacy questions require qualified legal
review before mainnet commercial launch.

### Eternl is the first native wallet integration

The site connects to Eternl through CIP-30 in the browser extension and Eternl
dApp browser. Check-ins use `signTx`, not a standalone `signData` message, because
the deadline must be updated on-chain.

### Successful check-ins spend only the network fee

The pulse consumes and recreates the canonical vault state with exactly the same
protected assets. A wallet input covers the Cardano transaction fee. The site
charges no pulse fee, and valid Plutus collateral is returned rather than spent.

## Frozen first-release decisions

1. Public product name, validator module, package metadata, and all newly minted
   protocol assets use **Baton**. The site retains a frozen rc.9 blueprint only
   so immutable legacy Preprod test plans remain actionable.
2. Include fixed and bearer release in the first audited validator; keep open
   recovery as a separate experimental validator.
3. Owner authority ends permanently at the final release boundary.
4. Default check-in period is 30 days and default release threshold is 3 missed
   check-ins; these are UI defaults, not necessarily on-chain constants.
5. The first release does not support in-place policy edits, liveness-key rotation,
   top-ups, or executor bounties; those require new specifications.
6. A terminal action burns the active receipt and mints a distinct completion
   receipt into the final payout.
7. The operator Preprod treasury address for the fixed 5 ADA setup fee is pinned
   in source and in the release manifest before transaction fixtures are frozen.

## Remaining launch choice

Decide the initial countries and U.S. states served after legal review; a
globally reachable website is not assumed to be globally lawful.
