/*
 * Adds a soft offset shadow around text using 10 staggered caster taps total.
 */

// Set to 0.0 to disable the shadow completely.
const float SHADOW_STRENGTH = 0.5;

// If you want to reduce the overall strength of the shadow based on how dim
// the text is, you can set the contrast thresholds for the strength scaling.
// Set MIN to 1.0 or MAX to 0.0 to disable strength scaling.

// Defines the minimum contrast from the bg needed to get any shadow treatment.
const float SHADOW_STRENGTH_SCALING_MIN_CONTRAST = 0.1;
// Defines how much contrast from the bg is needed to get a full-strength shadow.
const float SHADOW_STRENGTH_SCALING_MAX_CONTRAST = 0.5;

// Base shadow offset in pixels before the per-layer multipliers below.
const vec2  SHADOW_STEP_OFFSET = vec2(1.0, 2.0);

// Staggered layers keep the shadow from reading like a single copied glyph.
const float SHADOW_LAYER_OFFSETS[4] = float[4](0.75, 1.65, 2.55, 3.55);
const float SHADOW_LAYER_WEIGHTS[4] = float[4](0.44, 0.28, 0.18, 0.10);

// Shadow color in RGB
const vec3  SHADOW_COLOR = vec3(0.006, 0.007, 0.012);


float textMask(vec3 color)
{
    vec3 diff = abs(color - iBackgroundColor);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = length(diff);
    return smoothstep(0.08, 0.11, max(channelDelta, colorDelta * 0.65));
}

float luminance(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float colorDistance(vec3 a, vec3 b)
{
    vec3 diff = abs(a - b);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = abs(luminance(a) - luminance(b));
    return max(channelDelta, colorDelta);
}

float contrastFromBackground(vec3 color)
{
    return smoothstep(
        SHADOW_STRENGTH_SCALING_MIN_CONTRAST,
        SHADOW_STRENGTH_SCALING_MAX_CONTRAST,
        colorDistance(color, iBackgroundColor)
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 source = texture(iChannel0, uv);
    if (SHADOW_STRENGTH <= 0.0) {
        fragColor = source;
        return;
    }

    vec2 texel = 1.0 / iResolution.xy;
    vec2 shadowStep = SHADOW_STEP_OFFSET / iResolution.xy;
    vec2 shadowDirection = normalize(SHADOW_STEP_OFFSET);
    vec2 shadowCrossDirection = vec2(-shadowDirection.y, shadowDirection.x);

    float sourceText = textMask(source.rgb);
    float rawShadowMask = 0.0;
    float rawShadowContrast = 0.0;

    // Four non-linear layers read less like copied glyphs than even spacing.
    for (int i = 1; i <= 4; i++) {
        float offset = SHADOW_LAYER_OFFSETS[i - 1];
        float weight = SHADOW_LAYER_WEIGHTS[i - 1];
        vec2 casterUv = uv - shadowStep * offset;
        vec3 casterColor = texture(iChannel0, casterUv).rgb;

        // Spend edge-smoothing taps where they matter most: the contact layer.
        // Farther, weaker layers can use fewer taps with little visible loss.
        float casterText = textMask(casterColor);
        if (i == 1) {
            vec2 along = shadowDirection * 0.35 * texel;
            vec2 across = shadowCrossDirection * 0.35 * texel;
            casterText *= 0.50;
            casterText += textMask(texture(iChannel0, casterUv + along).rgb) * 0.125;
            casterText += textMask(texture(iChannel0, casterUv - along).rgb) * 0.125;
            casterText += textMask(texture(iChannel0, casterUv + across).rgb) * 0.125;
            casterText += textMask(texture(iChannel0, casterUv - across).rgb) * 0.125;
        } else if (i == 2) {
            vec2 diagonal = (shadowDirection + shadowCrossDirection) * 0.30 * texel;
            casterText *= 0.60;
            casterText += textMask(texture(iChannel0, casterUv + diagonal).rgb) * 0.20;
            casterText += textMask(texture(iChannel0, casterUv - diagonal).rgb) * 0.20;
        }
        rawShadowMask += casterText * weight;
        rawShadowContrast += contrastFromBackground(casterColor) * casterText * weight;
    }

    // Do not darken the source glyph itself, only pixels around it.
    float shadowMask = clamp(rawShadowMask * (1.0 - sourceText), 0.0, 1.0);

    float shadowContrastScale = rawShadowMask > 0.0 ? rawShadowContrast / rawShadowMask : 0.0;
    float shadowStrength = SHADOW_STRENGTH * shadowContrastScale;
    vec3 color = mix(source.rgb, SHADOW_COLOR, shadowMask * shadowStrength);

    fragColor = vec4(color, source.a);
}
