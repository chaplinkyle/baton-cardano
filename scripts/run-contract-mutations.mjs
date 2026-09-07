import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceContract = repository;
const aiken = process.env.AIKEN_BIN?.trim() || "aiken";
const mutations = [
  {
    name: "allow identical owner and check-in keys",
    from: "let distinct_keys = datum.owner != datum.liveness",
    to: "let distinct_keys = datum.owner == datum.liveness",
  },
  {
    name: "remove the one-shot seed requirement",
    from: "expect list.any(tx.inputs, fn(input) { input.output_reference == seed })",
    to: "expect True",
  },
  {
    name: "remove the check-in signature requirement",
    from: "let liveness_signed = list.has(tx.extra_signatories, old_datum.liveness)",
    to: "let liveness_signed = True",
  },
  {
    name: "allow release before the missed-check-in boundary",
    from: "expect validity_lower >= release_at(old_datum)",
    to: "expect validity_lower < release_at(old_datum)",
  },
  {
    name: "allow multiple bearer recovery inputs",
    from: "input_asset_quantity(tx.inputs, policy_id, asset_name) == 1",
    to: "input_asset_quantity(tx.inputs, policy_id, asset_name) >= 1",
  },
  {
    name: "remove exact value preservation during check-in",
    from: "let same_value = receipt_output.value == own_input.value",
    to: "let same_value = True",
  },
];

function runCheck(directory) {
  return spawnSync(
    aiken,
    ["check", directory, "--deny", "--seed", "20260906", "--max-success", "100"],
    { encoding: "utf8", windowsHide: true },
  );
}

const temporaryRoot = await mkdtemp(path.join(tmpdir(), "baton-mutations-"));
try {
  const baseline = path.join(temporaryRoot, "baseline");
  await mkdir(baseline);
  await Promise.all([
    cp(path.join(sourceContract, "aiken.toml"), path.join(baseline, "aiken.toml")),
    cp(path.join(sourceContract, "aiken.lock"), path.join(baseline, "aiken.lock")),
    cp(path.join(sourceContract, "validators"), path.join(baseline, "validators"), { recursive: true }),
  ]);
  try {
    await cp(path.join(sourceContract, "build"), path.join(baseline, "build"), { recursive: true });
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  const baselineResult = runCheck(baseline);
  if (baselineResult.error) throw baselineResult.error;
  if (baselineResult.status !== 0) {
    throw new Error(`Mutation baseline failed:\n${baselineResult.stdout}\n${baselineResult.stderr}`);
  }

  for (const [index, mutation] of mutations.entries()) {
    const candidate = path.join(temporaryRoot, `mutation-${index + 1}`);
    await cp(baseline, candidate, { recursive: true });
    const validatorPath = path.join(candidate, "validators", "baton.ak");
    const source = await readFile(validatorPath, "utf8");
    const occurrences = source.split(mutation.from).length - 1;
    if (occurrences !== 1) {
      throw new Error(`Mutation target for “${mutation.name}” occurred ${occurrences} times.`);
    }
    await writeFile(validatorPath, source.replace(mutation.from, mutation.to), "utf8");
    const result = runCheck(candidate);
    if (result.error) throw result.error;
    if (result.status === 0) {
      throw new Error(`SURVIVED: ${mutation.name}`);
    }
    console.log(`killed: ${mutation.name}`);
  }

  console.log(`PASS: ${mutations.length}/${mutations.length} security mutations were killed.`);
} finally {
  await rm(temporaryRoot, { recursive: true, force: true });
}
