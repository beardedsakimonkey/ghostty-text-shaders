// Shadow visibility.
const float SHADOW_STRENGTH = 0.8;

// Defines the minimum contrast from the bg needed to get any shadow treatment.
const float SHADOW_STRENGTH_SCALING_MIN_CONTRAST = 0.1;
// Defines how much contrast from the bg is needed to get a full-strength shadow.
const float SHADOW_STRENGTH_SCALING_MAX_CONTRAST = 0.5;

// Direction vector for the shadow. Magnitude is ignored; use distance below.
const vec2  SHADOW_DIRECTION = vec2(1.0, 2.0);

// Maximum shadow reach in physical pixels.
const float SHADOW_DISTANCE_PX = 7.95;

// Shadow color in RGB.
const vec3  SHADOW_COLOR = vec3(0.006, 0.007, 0.012);

// Fine-tune the relative weights of shadow layers (should sum to ~1.0).
const float SHADOW_LAYER_WEIGHTS[4] = float[4](0.44, 0.28, 0.18, 0.10);


float textMask(vec3 color)
{
    vec3 diff = abs(color - iBackgroundColor);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = length(diff);
    return smoothstep(0.08, 0.11, max(channelDelta, colorDelta * 0.65));
}

float colorDistance(vec3 a, vec3 b)
{
    vec3 diff = abs(a - b);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    return max(channelDelta, length(diff) * 0.65);
}

float contrastFromBackground(vec3 color)
{
    return smoothstep(
        SHADOW_STRENGTH_SCALING_MIN_CONTRAST,
        SHADOW_STRENGTH_SCALING_MAX_CONTRAST,
        colorDistance(color, iBackgroundColor)
    );
}

vec2 normalizedDirection(vec2 direction)
{
    float len = length(direction);
    return len > 0.0 ? direction / len : vec2(1.0, 0.0);
}

float shadowLayerPosition(float layer)
{
    float t = layer / 4.0;
    return t * (0.8 + 0.2 * t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 source = texture(iChannel0, uv);

    vec2 texel = 1.0 / iResolution.xy;
    vec2 shadowDirection = normalizedDirection(SHADOW_DIRECTION);
    vec2 shadowCrossDirection = vec2(-shadowDirection.y, shadowDirection.x);

    float sourceText = textMask(source.rgb);
    float rawShadowMask = 0.0;
    float rawShadowContrast = 0.0;

    // Four non-linear layers read less like copied glyphs than even spacing.
    for (int i = 1; i <= 4; i++) {
        float layerPosition = shadowLayerPosition(float(i));
        float weight = SHADOW_LAYER_WEIGHTS[i - 1];
        vec2 casterUv = uv - shadowDirection * SHADOW_DISTANCE_PX * layerPosition / iResolution.xy;
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
