# Release candidate 0.1.0-rc.10

This artifact is for Cardano Preprod review only. It must not be represented as
a Mainnet release.

```bash
npm run release:verify
```

The verifier binds the Aiken source, tests, compiled blueprint, specifications,
evidence, compiler metadata, and release controls to one source-set hash. This
candidate uses `BATON`, `BATON_COMPLETE`, and `BATON_RECOVERY` as its on-chain
asset names. The frozen rc.9 blueprint remains available only for compatibility
with immutable plans created before the Baton naming transition.

Mainnet remains blocked by the unchecked items in
[`docs/RELEASE_CHECKLIST.md`](../docs/RELEASE_CHECKLIST.md), including an
independent audit, legal review, long-running soak, public security testing, and
a capped pilot plan.
