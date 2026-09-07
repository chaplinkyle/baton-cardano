# Security policy

Baton is pre-release financial software. Do not use it with Mainnet or valuable
assets. The supported artifact is the exact Preprod candidate recorded in
[`release/release-manifest.json`](release/release-manifest.json).

## Report a vulnerability

Please use GitHub's **Report a vulnerability** flow to open a private security
advisory. Do not publish exploit details, keys, seed phrases, signed
transactions, or personal information in an issue.

Include the validator hash, a minimal reproduction, expected and actual
behavior, impact, and whether the issue was exercised in an emulator or on a
public testnet. No bounty is promised unless a separate program says otherwise.

The protocol cannot pause, upgrade, reverse, or recover an existing plan. If a
validator issue is discovered, stop creating plans and close still-active
testnet plans where possible.
