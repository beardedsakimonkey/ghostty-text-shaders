# Ghostty Text Shaders

Give your [Ghostty](https://github.com/ghostty-org/ghostty) terminal a Web 2.0
style makeover using shaders!

## Screenshot

<p align="center">
  <a href="https://github.com/sonph/onehalf">One Half Dark</a> /
  <a href="https://usgraphics.com/products/berkeley-mono">Berkeley Mono</a>:
</p>

<p align="center">
   <img width="947" height="872" alt="One Half screenshot" src="https://github.com/user-attachments/assets/85777feb-4134-4d38-ab9c-6539ed3e631f" />
</p>

## Installation

Clone and copy the shaders into your Ghostty config directory (usually
`~/.config/ghostty`):

```sh
git clone https://github.com/beardedsakimonkey/ghostty-text-shaders.git
mkdir -p ~/.config/ghostty
cp ghostty-text-shaders/*.glsl ~/.config/ghostty/
```

Then append the custom-shader options to your Ghostty `config`:

```sh
cat ghostty-text-shaders/config >> ~/.config/ghostty/config
```

or just copy-paste this into your `config`:

```
custom-shader = text-gradient.glsl
```

## Configuration

There are various constants in each shader that can be configured to your
liking. The most impactful knobs are:

- `GRADIENT_STRENGTH`
- `SHADOW_STRENGTH`
- `SHINE_STRENGTH`
- `SHINE_BALANCE`

## Shader Snapshot Tests

`text-gradient.glsl` has snapshot regression tests that render the
shader in a small WebGL harness with synthetic terminal fixtures.

```sh
bun install
bunx playwright install chromium
bun run test:shader
```

To intentionally refresh the golden PNGs after a shader change:

```sh
bun run test:shader:update
```

## More Ghostty Shaders

- <https://github.com/sahaj-b/ghostty-cursor-shaders>
- <https://github.com/0xhckr/ghostty-shaders>
