/*
 * Applies animated scanline brightness modulation across the full terminal
 * surface, with separate strengths for background and text pixels.
 */

// Visibility of scanlines on the background.
const float SCANLINE_BG_STRENGTH = 0.05;

// Visibility of scanlines on the foreground text.
const float SCANLINE_FG_STRENGTH = 0.0;

// Scanline frequency independent of the window size.
const float SCANLINE_PERIOD_PX = 20.0;

// Blends the scanline shape from a smooth sine wave at 0.0 to a hard striped
// on/off pattern at 1.0.
const float SCANLINE_SHARPNESS = 0.0;

// Scanline direction: (0,1) → horizontal, (1,0) → vertical, (1,1) → diagonal
const vec2  SCANLINE_DIRECTION = vec2(1.0, 1.0);

// Animation speed for scrolling the scanline pattern.
const float SCANLINE_SPEED = 0.0;


float textMask(vec3 color)
{
    vec3 diff = abs(color - iBackgroundColor);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = length(diff);
    return smoothstep(0.08, 0.18, max(channelDelta, colorDelta * 0.65));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);
    float text = textMask(color.rgb);

    // Project each pixel onto the configured scanline axis, then generate a
    // repeating brightness waveform across that 1D position.
    float scanPosition = dot(fragCoord.xy, normalize(SCANLINE_DIRECTION));
    float scanline = 0.5 + 0.5 * sin((scanPosition / SCANLINE_PERIOD_PX) * 6.28318530718 - iTime * SCANLINE_SPEED);

    // Blend between smooth sine modulation and a hard on/off stripe pattern.
    scanline = mix(scanline, step(0.5, scanline), SCANLINE_SHARPNESS);

    // Text and background can carry different scanline amounts.
    float scanlineStrength = mix(SCANLINE_BG_STRENGTH, SCANLINE_FG_STRENGTH, text);
    float scanlineMultiplier = (1.0 - scanlineStrength) + (scanline * scanlineStrength);
    color.rgb *= scanlineMultiplier;

    fragColor = vec4(color);
}
