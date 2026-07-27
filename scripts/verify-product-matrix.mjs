import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const fail = (message) => {
  throw new Error(`PRODUCT MATRIX CHECK FAILED: ${message}`);
};
const expect = (condition, message) => {
  if (!condition) fail(message);
};
const unique = (items, label) => {
  expect(new Set(items).size === items.length, `${label} must be unique`);
};
const plistString = (path, key) => {
  const match = read(path).match(new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`));
  return match?.[1];
};
const filesBelow = (relativePath) => {
  const output = [];
  const visit = (absolutePath) => {
    for (const name of readdirSync(absolutePath)) {
      const child = resolve(absolutePath, name);
      if (statSync(child).isDirectory()) visit(child);
      else output.push(child);
    }
  };
  visit(resolve(root, relativePath));
  return output;
};

const matrix = JSON.parse(read("config/product-matrix.v1.json"));
expect(matrix.schemaVersion === 1, "unsupported schema version");
expect(
  JSON.stringify(matrix.reservedEditions) === JSON.stringify(["personal", "pro"]),
  "private and Pro editions must remain reserved",
);

const expectedIds = ["macos-public", "windows-public"];
const actualIds = matrix.products.map((item) => item.id).sort();
expect(JSON.stringify(actualIds) === JSON.stringify([...expectedIds].sort()), "exactly two public products must be enabled");
expect(matrix.products.every((item) => item.edition === "public"), "only public editions may be registered");

unique(matrix.products.map((item) => item.id), "product IDs");
unique(matrix.products.map((item) => item.productIdentifier), "product identifiers");
unique(matrix.products.map((item) => item.storageNamespace), "storage namespaces");
unique(matrix.products.map((item) => item.artifactPath), "artifact paths");
unique(matrix.products.flatMap((item) => item.storageKeys), "storage keys");

for (const product of matrix.products) {
  expect(["macos", "windows"].includes(product.platform), `${product.id} platform`);
  expect(product.sharedContract === "public-core-v1", `${product.id} shared contract`);
  expect(existsSync(resolve(root, product.builder.script)), `${product.id} builder is missing`);
  expect(existsSync(resolve(root, product.artifactVerifier)), `${product.id} verifier is missing`);
  expect(
    !product.features.some((feature) => product.forbiddenCapabilities.includes(feature)),
    `${product.id} enables a forbidden capability`,
  );
}

const macPublic = matrix.products.find((item) => item.id === "macos-public");
const windowsPublic = matrix.products.find((item) => item.id === "windows-public");
expect(JSON.stringify(macPublic.compileDefines) === JSON.stringify(["EDITION_PUBLIC"]), "macOS Public compile closure changed");
expect(macPublic.releaseStatus === "public", "macOS Public release status drifted");
expect(windowsPublic.releaseStatus === "candidate", "Windows must remain a candidate until real-device acceptance");
expect(macPublic.storageNamespace === macPublic.storageKeys[0], "macOS Public storage namespace drifted");

expect(plistString("Resources/Info.plist", "CFBundleIdentifier") === macPublic.productIdentifier, "Public Bundle ID drifted");
expect(plistString("Resources/Info.plist", "CFBundleDisplayName") === macPublic.applicationName, "Public display name drifted");
expect(plistString("Resources/Info.plist", "CFBundleName") === macPublic.applicationName, "Public bundle name drifted");
expect(macPublic.artifactPath.endsWith(`/${macPublic.applicationName}.app`), "Public artifact name drifted");

const editionSource = read("Sources/PomodoredTimer/AppEdition.swift");
for (const value of [macPublic.productIdentifier, ...macPublic.storageKeys]) {
  expect(editionSource.includes(value), `AppEdition is missing ${value}`);
}
expect(!existsSync(resolve(root, "Sources/PomodoredTimer/YouTubeMusicPlayer.swift")), "private media source must not exist");

const sourceText = filesBelow("Sources").map((path) => readFileSync(path, "utf8")).join("\n");
for (const forbidden of [
  "jp.tomica.pomodoredtimer\"",
  "pomodored.timer.state.v1",
  "pomodored.window.compact.v1",
  "pomodored.window.alwaysOnTop.v1",
]) {
  expect(!sourceText.includes(forbidden), `private identity leaked into public source: ${forbidden}`);
}

const macBuilder = read("scripts/build-app.sh");
expect(macBuilder.includes("-D EDITION_PUBLIC"), "macOS builder is missing EDITION_PUBLIC");
expect(!macBuilder.includes("EDITION_PERSONAL"), "macOS builder contains a private edition");

const windowsProject = read("Windows/src/PomodoredTimer.Windows.Public/PomodoredTimer.Windows.Public.csproj");
expect(windowsProject.includes(windowsPublic.productIdentifier), "Windows assembly identity drifted");
const windowsStore = read("Windows/src/PomodoredTimer.Application/PublicStateStore.cs");
expect(windowsStore.includes('"PomodoredTimer"') && windowsStore.includes('"Public"'), "Windows storage namespace drifted");
for (const key of windowsPublic.storageKeys) {
  expect(windowsStore.includes(`"${key}"`), `Windows store is missing ${key}`);
}
const windowsState = read("Windows/src/PomodoredTimer.Domain/TimerModels.cs");
expect(windowsState.includes('= "windows";') && windowsState.includes('= "public";'), "Windows state identity drifted");

const ci = read(".github/workflows/ci.yml");
expect(ci.includes("node scripts/verify-product-matrix.mjs"), "CI does not run the product matrix verifier");
for (const product of matrix.products) {
  const invocation = [`./${product.builder.script}`, ...product.builder.arguments].join(" ");
  expect(ci.includes(invocation), `CI does not build ${product.id}`);
}

console.log("PASS: public repository defines isolated macOS and Windows products only");
