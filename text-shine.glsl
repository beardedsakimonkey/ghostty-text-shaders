/*
 * Adds subtle text depth by brightening the lower inset edge of glyphs and
 * slightly dimming the rest of the glyph to keep overall brightness balanced.
 */

// Set to 0.0 to disable the shine completely.
const float SHINE_STRENGTH = 0.4;

// If you want to reduce the overall strength of the shine based on how dim
// the text is, you can set the contrast thresholds for the strength scaling.
// Set MIN to 1.0 or MAX to 0.0 to disable strength scaling.

// Defines the minimum contrast from the bg needed to get any shine treatment.
const float SHINE_STRENGTH_SCALING_MIN_CONTRAST = 0.0;

// Defines how much contrast from the bg is needed to get a full-strength sine.
const float SHINE_STRENGTH_SCALING_MAX_CONTRAST = 0.6;

// Dim the body of the glyph slightly so the inset highlight does not push the
// overall perceived brightness too high.
const float SHINE_BALANCE = 0.15;

// Number of inward pixel rows sampled from the lower edge of the glyph.
const float SHINE_THICKNESS_PX = 3.0;

// Sample spread of the three shine layers in physical pixels.
const float SHINE_LAYER_SPREADS[3] = float[3](0.5, 1.0, 1.5);
// Relative contribution of the three shine layers.
const float SHINE_LAYER_WEIGHTS[3] = float[3](0.5, 0.3, 0.3);


float textMask(vec3 color)
{
    vec3 diff = abs(color - iBackgroundColor);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = length(diff);
    return smoothstep(0.08, 0.18, max(channelDelta, colorDelta * 0.65));
}

float luminance(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float contrastFromBackground(vec3 color)
{
    float contrast = abs(luminance(color) - luminance(iBackgroundColor));
    return smoothstep(
        SHINE_STRENGTH_SCALING_MIN_CONTRAST,
        SHINE_STRENGTH_SCALING_MAX_CONTRAST,
        contrast
    );
}

float shineLayerMask(vec2 uv, float text, float spreadPx)
{
    vec2 shineSpread = spreadPx / iResolution.xy;
    float shineMask = 0.0;
    float shineWeight = 0.0;

    // Walk upward from the lower glyph edge to build an inset highlight band.
    for (int i = 1; i <= 4; i++) {
        float insetPx = float(i);
        if (insetPx > SHINE_THICKNESS_PX) {
            continue;
        }

        vec2 shineStep = vec2(0.0, insetPx) / iResolution.xy;
        float shiftedText = textMask(texture(iChannel0, uv - shineStep).rgb);
        shiftedText = min(shiftedText, textMask(texture(iChannel0, uv - shineStep - vec2(0.0, shineSpread.y)).rgb));

        // The contact row gets horizontal taps too, which helps the highlight
        // wrap around rounded lower corners rather than reading as a flat stripe.
        if (i == 1) {
            shiftedText = min(shiftedText, textMask(texture(iChannel0, uv - shineStep - vec2(shineSpread.x, 0.0)).rgb));
            shiftedText = min(shiftedText, textMask(texture(iChannel0, uv - shineStep + vec2(shineSpread.x, 0.0)).rgb));
        }

        float weight = 1.0 - ((insetPx - 1.0) / max(SHINE_THICKNESS_PX, 1.0));
        shineMask += text * (1.0 - shiftedText) * weight;
        shineWeight += weight;
    }
    return shineWeight > 0.0 ? shineMask / shineWeight : 0.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);
    if (all(equal(color.rgb, iBackgroundColor))) {
        fragColor = color;
        return;
    }

    float text = textMask(color.rgb);

    float shineMask = 0.0;
    for (int i = 0; i < 3; i++) {
        shineMask += shineLayerMask(uv, text, SHINE_LAYER_SPREADS[i]) * SHINE_LAYER_WEIGHTS[i];
    }
    shineMask = smoothstep(0.0, 1.0, shineMask);

    // Favor stronger shine on clearly text-like pixels with enough contrast to
    // carry the effect cleanly.
    float shineBrightnessWeight = contrastFromBackground(color.rgb);
    float shineTextStrength = smoothstep(0.55, 1.0, text);
    float shineLift = shineMask * SHINE_STRENGTH * shineTextStrength * shineBrightnessWeight;
    float shineCompensation = text * SHINE_BALANCE;
    float shineBrightness = 1.0 + shineLift - shineCompensation;
    color.rgb = clamp(color.rgb * shineBrightness, 0.0, 1.0);

    fragColor = color;
}
