# Preprod rehearsal

Use the exact frozen release artifact. Do not substitute a rebuilt site or
blueprint after recording the release manifest.

1. Confirm the source-pinned Preprod operator treasury address and prepare two
   unrelated Eternl test accounts for owner and check-in authority.
2. Verify `npm run release:verify` and record the source-set hash.
3. Create and confirm a fixed-destination vault with low-value test ADA.
4. Perform at least five confirmed pulses, including one near a scheduled
   check-in boundary. Record every transaction ID and observed sequence.
5. Close that vault with the owner key and confirm the full protected bundle.
6. Create a short fixed vault, intentionally miss the schedule, and have an
   unrelated executor release it to the pinned destination.
7. Create a bearer vault and confirm its one-shot recovery token was minted to
   the owner outside the vault. Transfer it to another test wallet. After expiry,
   prove an unrelated wallet without the token cannot construct release, then
   release from the token holder.
8. Repeat provider reads and release construction after intentionally retaining
   a stale manifest/state snapshot.
9. Confirm each official creation paid exactly 5 ADA to the recorded treasury,
   while pulse, close, and release paid zero site fee.
10. Rebuild on a clean machine and compare validator, blueprint, and source-set
    hashes byte for byte.

Record results in a signed or committed testnet evidence file containing network,
release version, validator hash, treasury address, transaction IDs, timestamps,
fees, transaction sizes, and pass/fail notes. Never place private keys or seed
phrases in that file.

## Unattended software-wallet rehearsal

The repository includes an isolated software-wallet runner so the transaction
lifecycle does not depend on Eternl approval dialogs:

```text
npm run preprod:wallet:init
npm run preprod:wallet:status
npm run preprod:automated
```

Wallet generation is hard-locked to testnet addresses. Test-only private keys
are written to `.preprod-wallets/wallets.json` by the companion interface tools,
which exclude that directory from Git,
and are never included in the generated evidence. Never send Mainnet ADA or
assets to these addresses.

The public Cardano faucet requires either its browser reCAPTCHA or an issued API
key. Fund only the generated `owner` address with at least 250 test ADA. The
runner then funds its own action wallets and automatically executes three public
Preprod paths: five pulses plus owner close, unrelated-executor fixed release,
and rejected non-holder plus successful recovery-token-holder bearer release.
Its transaction journal is written below `artifacts/preprod-automation/`.

An automated run is execution evidence, not independent review. Promote its
records into the schema-two release evidence only after the clean-machine
rebuild and human review gates are complete.
