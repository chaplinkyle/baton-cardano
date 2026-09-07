# Contributing

Baton welcomes focused security fixes, test cases, documentation corrections,
and reproducibility improvements.

1. Open an issue for behavior changes. Use a private security advisory for
   vulnerabilities.
2. Keep protocol changes separate from interface concerns.
3. Add a regression test for every validator change.
4. Run `npm test`, `npm run test:mutations`, `npm run build`, and
   `npm run release:verify` before requesting review.
5. Never commit wallet files, signing keys, mnemonics, or Mainnet transaction
   material.

Protocol changes invalidate the recorded release manifest and require a new
candidate, new public testnet evidence, and renewed independent review.
