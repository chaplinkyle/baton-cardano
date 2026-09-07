# Preprod evidence format

The Preprod rehearsal is complete only when one committed JSON evidence file
contains the frozen artifact identity and every transaction used in the run.
Screenshots may supplement this record but do not replace it.

```json
{
  "schemaVersion": 2,
  "release": "0.1.0-rc.10",
  "network": "Preprod",
  "sourceSetSha256": "64 lowercase hex characters",
  "blueprintSha256": "64 lowercase hex characters",
  "validatorHash": "56 lowercase hex characters",
  "treasuryAddress": "addr_test1...",
  "startedAt": "ISO-8601 timestamp",
  "completedAt": "ISO-8601 timestamp",
  "runs": [
    {
      "path": "fixed-close | fixed-release | bearer-release",
      "vaultId": "receipt policy and asset identifier",
      "ownerAddress": "addr_test1...",
      "livenessAddress": "addr_test1...",
      "periodMs": 86400000,
      "missesToRelease": 3,
      "lastCheckInAt": "ISO-8601 timestamp",
      "releaseAt": "ISO-8601 timestamp",
      "transactions": [
        {
          "action": "create | pulse | close | rejected-release | release",
          "submitterAddress": "addr_test1...",
          "txId": "64 lowercase hex characters, or null for a rejected build",
          "confirmedAt": "ISO-8601 timestamp, or null",
          "networkFeeLovelace": "decimal string, or null",
          "siteFeeLovelace": "decimal string",
          "transactionBytes": 0,
          "sequence": 0,
          "stateLastCheckInAt": "ISO-8601 timestamp",
          "stateReleaseAt": "ISO-8601 timestamp",
          "result": "pass | fail",
          "notes": "No secrets or seed phrases"
        }
      ]
    }
  ],
  "cleanMachineRebuild": {
    "sourceSetSha256": "64 lowercase hex characters",
    "blueprintSha256": "64 lowercase hex characters",
    "validatorHash": "56 lowercase hex characters",
    "result": "pass | fail"
  },
  "reviewedBy": "person or organization",
  "reviewedAt": "ISO-8601 timestamp"
}
```

Each fixed-release run also records `destinationAddress` and
`executorAddress`. Each bearer-release run records `recoveryUnit`,
`recoveryTokenHolderAddress`, and `nonHolderAddress`. The recovery unit must use
the vault's policy ID and the `BATON_RECOVERY` asset name.

Validate the completed file from the repository root:

```text
npm run preprod:verify -- release/preprod-evidence.json
```

Every successful transaction ID must resolve on a Cardano Preprod explorer.
The fixed-release run must contain a release submitted by a wallet unrelated to
the owner. The bearer run must record both the failed non-holder attempt and the
successful recovery-token-holder release. Official creations must show exactly
5,000,000 lovelace of site fee; every other action must show zero site fee.

The evidence file must reference, but must not alter, the frozen release
manifest. Any source or blueprint change invalidates the rehearsal and requires
a new release candidate and a new evidence file.
