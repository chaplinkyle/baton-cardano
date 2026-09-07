import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { buildReleaseManifest, root } from "./release-lib.mjs";

const manifest = await buildReleaseManifest();
await mkdir(path.join(root, "release"), { recursive: true });
await writeFile(
  path.join(root, "release/release-manifest.json"),
  `${JSON.stringify(manifest, null, 2)}\n`,
);
console.log(`Generated ${manifest.release} manifest for ${manifest.contract.validatorHash}.`);
