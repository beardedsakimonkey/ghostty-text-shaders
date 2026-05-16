# Repository Guidelines

## Project Structure & Module Organization

This repository contains Ghostty custom shaders. Root-level `*.glsl` files are
the shader sources loaded by `config`, including `text-gradient.glsl`, `text-shadow.glsl`, and `text-shine.glsl`. Keep shader-specific logic in its own file unless a helper is already established locally.

Tests live under `tests/`. The WebGL harness is `tests/shader-harness.html`, fixture definitions are in `tests/fixtures/cases.mjs`, and committed golden PNGs are in `tests/goldens/`. Test artifacts and diffs are written to `tests/artifacts/` and should not be committed.

## Build, Test, and Development Commands

There is no build step for the shaders; Ghostty loads the GLSL files directly.

```sh
bun install
```

Installs the local test dependency pinned in `bun.lock`.

```sh
bunx playwright install chromium
```

Installs the browser used by the shader snapshot harness.

```sh
bun run test:shader
```

Renders `text-gradient.glsl` against all synthetic fixtures and compares the output to `tests/goldens/`.

```sh
bun run test:shader:update
```

Refreshes golden PNGs after intentional shader output changes.

## Coding Style & Naming Conventions

Use 4-space indentation in GLSL and 2-space indentation in JavaScript fixtures and harness code. Prefer `const float` configuration knobs near the top of shader files, with uppercase names such as `GRADIENT_STRENGTH`. Use lower camel case for helper functions, for example `colorDistance` or `estimatedColumnCenterX`. Keep comments short and focused on non-obvious shader behavior.

## Testing Guidelines

Add or update snapshot fixtures when changing background estimation, glyph masking, cursor dimension assumptions, or row/column sampling. Fixture names and golden filenames should be kebab-case, such as `vertical-bar-cell-background`. When tests fail, inspect `tests/artifacts/*-actual.png` and `*-diff.png` before updating goldens.

## Agent-Specific Instructions

Do not commit `node_modules/` or `tests/artifacts/`. Avoid unrelated formatting churn in shader files; small visual changes can produce broad snapshot diffs.

Local Ghostty documentation is bundled at `/Applications/Ghostty.app/Contents/Resources/ghostty/doc/`; prefer `ghostty.1.md` for CLI/config options. To validate a config file, use the equals form:

```sh
ghostty +validate-config --config-file=./path/to/config
```

This build rejects the space-separated form with `error.ValueRequired`. `error: SentryInitFailed` may still print on success; check the exit code.
