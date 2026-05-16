import { chromium } from "playwright";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { shaderSnapshotCases } from "./fixtures/cases.mjs";

const testsDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(testsDir, "..");
const shaderPath = path.join(rootDir, "text-gradient.glsl");
const harnessPath = path.join(testsDir, "shader-harness.html");
const goldenDir = path.join(testsDir, "goldens");
const artifactDir = path.join(testsDir, "artifacts");
const updateSnapshots = process.env.UPDATE_SHADER_SNAPSHOTS === "1" || process.argv.includes("--update");
const caseFilter =
  process.env.SHADER_SNAPSHOT_CASE ||
  process.argv.find((arg) => arg.startsWith("--case="))?.slice("--case=".length);

function pngPathFor(dir, name) {
  return path.join(dir, `${name}.png`);
}

function dataUrlToBuffer(dataUrl) {
  const marker = "base64,";
  const markerIndex = dataUrl.indexOf(marker);
  if (markerIndex === -1) {
    throw new Error("Expected a base64 data URL");
  }
  return Buffer.from(dataUrl.slice(markerIndex + marker.length), "base64");
}

async function writePng(dataUrl, filePath) {
  await writeFile(filePath, dataUrlToBuffer(dataUrl));
}

function comparePixels(expected, actual, width, height, tolerance) {
  const perChannelTolerance = tolerance.perChannel ?? 0;
  const maxMismatchRatio = tolerance.maxMismatchRatio ?? 0;
  const maxMismatchPixels = tolerance.maxMismatchPixels ?? 0;
  const allowedMismatches = Math.max(
    maxMismatchPixels,
    Math.floor(width * height * maxMismatchRatio)
  );

  let mismatches = 0;
  let maxDelta = 0;

  for (let i = 0; i < expected.length; i += 4) {
    const delta = Math.max(
      Math.abs(expected[i] - actual[i]),
      Math.abs(expected[i + 1] - actual[i + 1]),
      Math.abs(expected[i + 2] - actual[i + 2]),
      Math.abs(expected[i + 3] - actual[i + 3])
    );
    maxDelta = Math.max(maxDelta, delta);
    if (delta > perChannelTolerance) {
      mismatches += 1;
    }
  }

  return {
    pass: mismatches <= allowedMismatches,
    mismatches,
    allowedMismatches,
    maxDelta
  };
}

async function main() {
  await mkdir(goldenDir, { recursive: true });
  const shaderSource = await readFile(shaderPath, "utf8");
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(pathToFileURL(harnessPath).href);

  const failures = [];
  const selectedCases = caseFilter
    ? shaderSnapshotCases.filter((testCase) => testCase.name === caseFilter)
    : shaderSnapshotCases;

  if (caseFilter && selectedCases.length === 0) {
    throw new Error(`No shader snapshot case named "${caseFilter}"`);
  }

  for (const testCase of selectedCases) {
    const actual = await page.evaluate(
      ({ shaderSource: source, testCase: fixture }) => window.renderShaderCase(source, fixture),
      { shaderSource, testCase }
    );
    const goldenPath = pngPathFor(goldenDir, testCase.name);

    if (updateSnapshots || !existsSync(goldenPath)) {
      await writePng(actual.pngDataUrl, goldenPath);
      console.log(`${updateSnapshots ? "updated" : "created"} ${path.relative(rootDir, goldenPath)}`);
      continue;
    }

    const goldenBase64 = await readFile(goldenPath, "base64");
    const expected = await page.evaluate(
      (base64) => window.decodePngBase64(base64),
      goldenBase64
    );

    if (expected.width !== actual.width || expected.height !== actual.height) {
      failures.push(`${testCase.name}: dimensions changed from ${expected.width}x${expected.height} to ${actual.width}x${actual.height}`);
      await mkdir(artifactDir, { recursive: true });
      await writePng(actual.pngDataUrl, pngPathFor(artifactDir, `${testCase.name}-actual`));
      continue;
    }

    const result = comparePixels(
      expected.pixels,
      actual.pixels,
      actual.width,
      actual.height,
      testCase.tolerance || {}
    );

    if (!result.pass) {
      await mkdir(artifactDir, { recursive: true });
      const actualPath = pngPathFor(artifactDir, `${testCase.name}-actual`);
      const diffPath = pngPathFor(artifactDir, `${testCase.name}-diff`);
      const diffDataUrl = await page.evaluate(
        (args) => window.makeDiffPngDataUrl(args),
        {
          width: actual.width,
          height: actual.height,
          expectedPixels: expected.pixels,
          actualPixels: actual.pixels,
          perChannelTolerance: testCase.tolerance?.perChannel ?? 0
        }
      );
      await writePng(actual.pngDataUrl, actualPath);
      await writePng(diffDataUrl, diffPath);
      failures.push(
        `${testCase.name}: ${result.mismatches} mismatched pixels, allowed ${result.allowedMismatches}, max channel delta ${result.maxDelta}. ` +
        `See ${path.relative(rootDir, actualPath)} and ${path.relative(rootDir, diffPath)}.`
      );
    } else {
      console.log(`passed ${testCase.name}`);
    }
  }

  await browser.close();

  if (failures.length > 0) {
    for (const failure of failures) {
      console.error(failure);
    }
    process.exitCode = 1;
    return;
  }

  console.log(`Shader snapshots ${updateSnapshots ? "updated" : "passed"} (${selectedCases.length} cases).`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
