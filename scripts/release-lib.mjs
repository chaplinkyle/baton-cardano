import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const includedRoots = [".github", "docs", "evidence", "legacy", "scripts", "validators"];
const includedFiles = [
  ".gitattributes",
  ".gitignore",
  "README.md",
  "CONTRIBUTING.md",
  "LICENSE",
  "SECURITY.md",
  "aiken.lock",
  "aiken.toml",
  "package.json",
  "plutus.json",
  "release/README.md",
];
const ignoredSegments = new Set(["build", "node_modules", ".git"]);
const allowedExtensions = new Set([".ak", ".json", ".md", ".mjs", ".toml", ".yaml", ".yml"]);

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function normalizedTextSha256(value) {
  return sha256(value.replaceAll("\r\n", "\n"));
}

async function collectFiles(relativeDirectory) {
  const entries = await readdir(path.join(root, relativeDirectory), { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    if (ignoredSegments.has(entry.name)) continue;
    const relative = path.posix.join(relativeDirectory, entry.name);
    if (entry.isDirectory()) files.push(...await collectFiles(relative));
    else if (allowedExtensions.has(path.extname(entry.name))) files.push(relative);
  }
  return files;
}

export async function buildReleaseManifest() {
  const discovered = (await Promise.all(includedRoots.map(collectFiles))).flat();
  const files = [...new Set([...includedFiles, ...discovered])]
    .filter((file) => file !== "release/release-manifest.json")
    .sort();
  const sourceHashes = {};
  for (const file of files) {
    sourceHashes[file] = normalizedTextSha256(await readFile(path.join(root, file), "utf8"));
  }
  const sourceSetSha256 = sha256(
    Object.entries(sourceHashes).map(([file, hash]) => `${file}\0${hash}\n`).join(""),
  );

  const blueprintText = await readFile(path.join(root, "plutus.json"), "utf8");
  const blueprint = JSON.parse(blueprintText);
  const spend = blueprint.validators.find((candidate) => candidate.title === "baton.baton.spend");
  if (!spend) throw new Error("Compiled Baton spending validator is missing.");

  const testSource = await readFile(path.join(root, "validators/baton_test.ak"), "utf8");
  const totalTestCount = (testSource.match(/^test\s+/gm) ?? []).length;
  const propertyTestCount = (testSource.match(/^test\s+prop_/gm) ?? []).length;

  return {
    schemaVersion: 1,
    release: "0.1.0-rc.10",
    status: "preprod-review-only",
    network: "Preprod",
    contract: {
      language: "PlutusV3",
      compiler: blueprint.preamble.compiler.version,
      validatorHash: spend.hash,
      blueprintSha256: sha256(Buffer.from(blueprintText)),
      compiledCodeBytes: spend.compiledCode.length / 2,
      activeReceiptName: "BATON",
      terminalReceiptName: "BATON_COMPLETE",
      recoveryReceiptName: "BATON_RECOVERY",
      deterministicTestCount: totalTestCount - propertyTestCount,
      propertyTestCount,
      propertyIterationsPerTest: 1000,
      generatedPropertyCases: propertyTestCount * 1000,
      protocolFeeLovelace: "0",
    },
    limits: {
      maxMissesToRelease: 1000,
      maxValidityWindowMs: 900000,
    },
    sourceSetSha256,
    sourceHashes,
  };
}
