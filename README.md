# Ghostty Text Shaders

Give your [Ghostty](https://github.com/ghostty-org/ghostty) terminal a Web 2.0
style makeover using shaders!

You can either use all 4 glsl shaders together or pick and choose based on your
preference.

## Screenshot

<p align="center">
  <a href="https://github.com/sonph/onehalf">One Half Dark</a> /
  <a href="https://usgraphics.com/products/berkeley-mono">Berkeley Mono</a>:
</p>

<p align="center">
  <img width="853" height="519" src="https://github.com/user-attachments/assets/62d49a9f-e37b-4be7-9912-4df85a870645" alt="One Half screenshot">
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
custom-shader = text-shadow.glsl
custom-shader = text-shine.glsl
custom-shader = text-gradient.glsl
custom-shader = scanlines.glsl
```

## Configuration

There are various constants in each shader that can be configured to your
liking. The most impactful knobs are:

- `GRADIENT_STRENGTH`
- `SHADOW_STRENGTH`
- `SHINE_STRENGTH`
- `SHINE_BALANCE`

## More Ghostty Shaders

- <https://github.com/sahaj-b/ghostty-cursor-shaders>
- <https://github.com/0xhckr/ghostty-shaders>
