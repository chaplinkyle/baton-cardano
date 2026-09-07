import { readFile } from "node:fs/promises";
import path from "node:path";
import { isDeepStrictEqual } from "node:util";
import { buildReleaseManifest, root } from "./release-lib.mjs";

const recorded = JSON.parse(await readFile(path.join(root, "release/release-manifest.json"), "utf8"));
const actual = await buildReleaseManifest();
if (!isDeepStrictEqual(recorded, actual)) {
  throw new Error("Release verification failed: source, blueprint, compiler, or tests differ from the manifest.");
}
console.log(`Verified ${actual.release}.`);
console.log(`Validator hash: ${actual.contract.validatorHash}`);
console.log(`Source set SHA-256: ${actual.sourceSetSha256}`);
