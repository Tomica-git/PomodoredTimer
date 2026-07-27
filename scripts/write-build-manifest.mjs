import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const values = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!key?.startsWith("--") || value === undefined) {
    throw new Error("Build manifest arguments must be --key value pairs");
  }
  values.set(key.slice(2), value);
}

const required = [
  "output",
  "product",
  "edition",
  "release-status",
  "commit",
  "dirty",
  "platform",
  "architecture",
  "toolchain",
  "sdk",
  "artifact",
  "sha256",
];
for (const key of required) {
  if (!values.has(key)) throw new Error(`Missing --${key}`);
}

const output = resolve(values.get("output"));
const manifest = {
  schemaVersion: 1,
  product: values.get("product"),
  edition: values.get("edition"),
  releaseStatus: values.get("release-status"),
  source: {
    commit: values.get("commit"),
    dirty: values.get("dirty") === "true",
  },
  environment: {
    platform: values.get("platform"),
    architecture: values.get("architecture"),
    toolchain: values.get("toolchain"),
    sdk: values.get("sdk"),
  },
  artifact: {
    path: values.get("artifact"),
    sha256: values.get("sha256"),
  },
};

mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
