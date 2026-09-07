# Operations runbook

## Before creating any vault

Confirm the network, validator hash, applied policy ID, protected bundle,
schedule, release mode, destination or recovery token, 5 ADA site fee, network
fee, and transaction size on the final unsigned review. Export the recovery
manifest after confirmation and keep multiple offline copies.

Use separate owner and liveness keys. Keep the owner key in stronger storage;
the liveness key is the routine check-in credential. In bearer mode, keep the
recovery token outside the vault and secure it like a withdrawal key. Baton
mints this token during bearer-plan creation; do not send it to the vault address.

## Routine check-in

Read the canonical active-receipt UTxO from more than one provider when possible.
Construct the pulse from that confirmed state, review that protected-value
change is zero and site fee is zero, sign with the liveness key, and wait for the
new active-receipt UTxO to confirm. A wallet approval or submitted transaction
is not a successful check-in until chain confirmation is observed.

## Provider or wallet outage

Do not repeatedly sign stale drafts. Switch provider or wallet infrastructure,
reload the latest active-receipt UTxO, and rebuild. The validator accepts any compatible
builder; the official site is not required. Configure enough allowed misses to
survive realistic device, travel, provider, and chain disruptions.

## Lost liveness key

Before the final boundary, use the owner-close path and create a replacement
vault with a new liveness key. There is no key rotation or operator override in
version one.

## Lost owner key

The operator cannot recover or replace it. The liveness key can continue pulses
but cannot withdraw. If pulses stop, only the configured post-expiry release
path remains.

## Suspected validator vulnerability

Stop new creation immediately, preserve logs and release hashes, publish a clear
warning, and privately coordinate disclosure. Owners of still-live vaults should
consider owner-close after independently verifying the warning. Existing vaults
cannot be paused or upgraded by the website.

## Provider disagreement or stale state

Compare the active or completion receipt unit, transaction reference, inline
datum, sequence, value, and block confirmation across providers. Never merge
fields from different
observations. The transaction builder must consume one exact canonical UTxO;
once consumed, every draft based on it is stale.

## After expiry

Fixed release is permissionless to execute but can pay only the pinned output.
Bearer release requires an input holding exactly one configured recovery token and
pays the combined vault value and token to the selected key address. The executor
must fund normal network fees.
