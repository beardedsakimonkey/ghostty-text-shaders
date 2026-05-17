//========================================================================
// Gradient
//========================================================================
const float GRADIENT_STRENGTH = 0.3;

// Ramp up gradient strength based on text/background contrast.
const float GRADIENT_STRENGTH_RAMP_START = 0.1;
const float GRADIENT_STRENGTH_RAMP_END   = 0.5;

// Since Ghostty doesn't expose terminal cell dimensions, we estimate it using
// the cursor height. This shifts where the gradient starts within rows.
const float GRADIENT_Y_OFFSET_PX = -4.0;

// Smooth the gradient at the top of row to help with double/squiggly underlines.
const float GRADIENT_ROW_SEAM_SMOOTH_PX = 8.0;

// Start/stop position of the linear gradient going from row-bottom to row-top (0→1).
const float GRADIENT_START = 0.0;
const float GRADIENT_STOP  = 1.0;

//========================================================================
// Shadow
//========================================================================
const float SHADOW_STRENGTH = 0.8;

// Ramp up shadow strength based on text/background contrast.
const float SHADOW_STRENGTH_RAMP_START = 0.1;
const float SHADOW_STRENGTH_RAMP_END   = 0.5;

// Direction vector for the shadow. Magnitude is ignored; use distance below.
const vec2  SHADOW_DIRECTION = vec2(1.0, 2.0);

// Maximum shadow reach in physical pixels.
const float SHADOW_DISTANCE_PX = 8.0;

// Shadow color in RGB.
const vec3  SHADOW_COLOR = vec3(0.006, 0.007, 0.012);

// Fine-tune the relative weights of shadow layers (should sum to ~1.0).
const float SHADOW_LAYER_WEIGHTS[4] = float[4](0.44, 0.28, 0.18, 0.10);

//========================================================================
// Shine
//========================================================================
const float SHINE_STRENGTH = 0.4;

// Ramp up shine strength based on text/background contrast.
const float SHINE_STRENGTH_RAMP_START = 0.0;
const float SHINE_STRENGTH_RAMP_END   = 0.4;

// Dim the body of the glyph to compensate.
const float SHINE_BALANCE = 0.1;

// Fine-tune the sample spread/weights of each shine layer.
const float SHINE_LAYER_SPREADS[2] = float[2](0.5, 1.0);
const float SHINE_LAYER_WEIGHTS[2] = float[2](0.5, 0.5);

//------------------------------------------------------------------------


float f(float x)
{
    if (x >= 0.0031308) {
        return 1.055 * pow(x, 1.0 / 2.4) - 0.055;
    } else {
        return 12.92 * x;
    }
}

float f_inv(float x)
{
    if (x >= 0.04045) {
        return pow((x + 0.055) / 1.055, 2.4);
    } else {
        return x / 12.92;
    }
}

// Oklab <-> linear sRGB conversions from https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
// sRGB linear -> nonlinear transform from https://bottosson.github.io/posts/colorwrong/
vec4 toOklab(vec4 rgb)
{
    vec3 c = vec3(f_inv(rgb.r), f_inv(rgb.g), f_inv(rgb.b));
    float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
    float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
    float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;

    float l_ = pow(l, 1.0 / 3.0);
    float m_ = pow(m, 1.0 / 3.0);
    float s_ = pow(s, 1.0 / 3.0);

    return vec4(
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
            rgb.a
            );
}

vec4 toRgb(vec4 oklab)
{
    vec3 c = oklab.rgb;
    float l_ = c.r + 0.3963377774 * c.g + 0.2158037573 * c.b;
    float m_ = c.r - 0.1055613458 * c.g - 0.0638541728 * c.b;
    float s_ = c.r - 0.0894841775 * c.g - 1.2914855480 * c.b;

    float l = l_ * l_ * l_;
    float m = m_ * m_ * m_;
    float s = s_ * s_ * s_;

    vec3 linear_srgb = vec3(
            +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
            );

    return vec4(
            clamp(f(linear_srgb.r), 0.0, 1.0),
            clamp(f(linear_srgb.g), 0.0, 1.0),
            clamp(f(linear_srgb.b), 0.0, 1.0),
            oklab.a
            );
}

vec4 applyOkLabBrightness(vec4 color, float brightness)
{
    color = toOklab(color);
    color.x = clamp(color.x * brightness, 0.0, 1.0);
    return toRgb(color);
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

// Cell-local background detection. Ghostty only exposes the rendered texture,
// so app-painted backgrounds are inferred from pixels near the row edges.
const float CELL_BG_SAMPLE_INSET_PX = 1.0;
const float CELL_BG_AGREE_MIN_DELTA = 0.01;
const float CELL_BG_AGREE_MAX_DELTA = 0.05;
const float CELL_BG_CENTER_MIN_AGREEMENT = 0.75;
const float CELL_BG_SIDE_SAMPLE_FRACTION = 0.12;
const float CELL_BG_SIDE_MIN_AGREEMENT = 0.75;
const float CELL_BG_SIDES_MIN_AGREEMENT = 0.75;
const float CELL_BG_SINGLE_EDGE_MIN_AGREEMENT = 0.75;
const float CELL_BG_SINGLE_EDGE_INNER_OFFSET_PX = 4.0;
const float CELL_BG_SPLIT_BLOCK_MIN_DELTA = 0.5;

float backgroundSampleAgreement(vec3 a, vec3 b)
{
    return 1.0 - smoothstep(
        CELL_BG_AGREE_MIN_DELTA,
        CELL_BG_AGREE_MAX_DELTA,
        colorDistance(a, b)
    );
}

float textMask(vec3 color, vec3 background)
{
    vec3 diff = abs(color - background);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = abs(luminance(color) - luminance(background));
    return smoothstep(0.08, 0.35, max(channelDelta, colorDelta));
}

float contrastMask(vec3 color, vec3 background, float minContrast, float maxContrast)
{
    vec3 diff = abs(color - background);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = abs(luminance(color) - luminance(background));
    return smoothstep(
        minContrast,
        maxContrast,
        max(channelDelta, colorDelta)
    );
}

float gradientContrastFromBackground(vec3 color, vec3 background)
{
    return contrastMask(
        color,
        background,
        GRADIENT_STRENGTH_RAMP_START,
        GRADIENT_STRENGTH_RAMP_END
    );
}

float shineContrastFromBackground(vec3 color, vec3 background)
{
    return contrastMask(
        color,
        background,
        SHINE_STRENGTH_RAMP_START,
        SHINE_STRENGTH_RAMP_END
    );
}

bool shouldTreatText(vec3 color, vec3 background)
{
    // Dark text on a light background does not read well with gradient/shine.
    return luminance(color) > luminance(background);
}

float shadowTextMask(vec3 color)
{
    vec3 diff = abs(color - iBackgroundColor);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = length(diff);
    return smoothstep(0.08, 0.11, max(channelDelta, colorDelta * 0.65));
}

float shadowColorDistance(vec3 a, vec3 b)
{
    vec3 diff = abs(a - b);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    return max(channelDelta, length(diff) * 0.65);
}

float shadowContrastFromBackground(vec3 color)
{
    return smoothstep(
        SHADOW_STRENGTH_RAMP_START,
        SHADOW_STRENGTH_RAMP_END,
        shadowColorDistance(color, iBackgroundColor)
    );
}

vec2 shadowNormalizedDirection(vec2 direction)
{
    float len = length(direction);
    return len > 0.0 ? direction / len : vec2(1.0, 0.0);
}

float shadowLayerPosition(float layer)
{
    float t = layer / 4.0;
    return t * (0.8 + 0.2 * t);
}

vec4 applyTextShadow(vec2 fragCoord, vec4 source)
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec2 texel = 1.0 / iResolution.xy;
    vec2 shadowDirection = shadowNormalizedDirection(SHADOW_DIRECTION);
    vec2 shadowCrossDirection = vec2(-shadowDirection.y, shadowDirection.x);

    float sourceText = shadowTextMask(source.rgb);
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
        float casterText = shadowTextMask(casterColor);
        if (i == 1) {
            vec2 along = shadowDirection * 0.35 * texel;
            vec2 across = shadowCrossDirection * 0.35 * texel;
            casterText *= 0.50;
            casterText += shadowTextMask(texture(iChannel0, casterUv + along).rgb) * 0.125;
            casterText += shadowTextMask(texture(iChannel0, casterUv - along).rgb) * 0.125;
            casterText += shadowTextMask(texture(iChannel0, casterUv + across).rgb) * 0.125;
            casterText += shadowTextMask(texture(iChannel0, casterUv - across).rgb) * 0.125;
        } else if (i == 2) {
            vec2 diagonal = (shadowDirection + shadowCrossDirection) * 0.30 * texel;
            casterText *= 0.60;
            casterText += shadowTextMask(texture(iChannel0, casterUv + diagonal).rgb) * 0.20;
            casterText += shadowTextMask(texture(iChannel0, casterUv - diagonal).rgb) * 0.20;
        }
        rawShadowMask += casterText * weight;
        rawShadowContrast += shadowContrastFromBackground(casterColor) * casterText * weight;
    }

    // Do not darken the source glyph itself, only pixels around it.
    float shadowMask = clamp(rawShadowMask * (1.0 - sourceText), 0.0, 1.0);

    float shadowContrastScale = rawShadowMask > 0.0 ? rawShadowContrast / rawShadowMask : 0.0;
    float shadowStrength = SHADOW_STRENGTH * shadowContrastScale;
    vec3 color = mix(source.rgb, SHADOW_COLOR, shadowMask * shadowStrength);

    return vec4(color, source.a);
}

vec3 sampleSourceCoord(vec2 coord)
{
    vec2 uv = clamp(coord / iResolution.xy, vec2(0.0), vec2(1.0));
    return texture(iChannel0, uv).rgb;
}

float sampleTextMask(vec2 uv, vec3 background)
{
    return textMask(texture(iChannel0, clamp(uv, vec2(0.0), vec2(1.0))).rgb, background);
}

float shineLayerMask(vec2 uv, vec3 background, float text, float spreadPx)
{
    vec2 shineSpread = spreadPx / iResolution.xy;
    float shineMask = 0.0;
    float shineWeight = 0.0;

    // Walk upward from the lower glyph edge to build an inset highlight band.
    for (int i = 1; i <= 2; i++) {
        float insetPx = float(i);
        vec2 shineStep = vec2(0.0, insetPx) / iResolution.xy;
        float shiftedText = sampleTextMask(uv - shineStep, background);
        shiftedText = min(
            shiftedText,
            sampleTextMask(uv - shineStep - vec2(0.0, shineSpread.y), background)
        );

        // The contact row gets horizontal taps too, which helps the highlight
        // wrap around rounded lower corners rather than reading as a flat stripe.
        if (i == 1) {
            shiftedText = min(
                shiftedText,
                sampleTextMask(uv - shineStep - vec2(shineSpread.x, 0.0), background)
            );
            shiftedText = min(
                shiftedText,
                sampleTextMask(uv - shineStep + vec2(shineSpread.x, 0.0), background)
            );
        }

        float weight = 1.0 - ((insetPx - 1.0) / 2.0);
        shineMask += text * (1.0 - shiftedText) * weight;
        shineWeight += weight;
    }
    return shineWeight > 0.0 ? shineMask / shineWeight : 0.0;
}

float estimatedColumnSampleX(
    float x,
    float cellOriginX,
    float cellWidth,
    float cellOffset,
    float cellFraction
)
{
    float cellIndex = floor((x - cellOriginX) / cellWidth) + cellOffset;
    return cellOriginX + (cellIndex + cellFraction) * cellWidth;
}

float estimatedColumnCenterX(
    float x,
    float cellOriginX,
    float cellWidth,
    float cellOffset
)
{
    return estimatedColumnSampleX(x, cellOriginX, cellWidth, cellOffset, 0.5);
}

float estimatedRowBottom(float y, float rowHeight)
{
    float shiftedY = y + GRADIENT_Y_OFFSET_PX;
    return floor(shiftedY / rowHeight) * rowHeight - GRADIENT_Y_OFFSET_PX;
}

float cellBackgroundSampleInset(float rowHeight)
{
    return min(CELL_BG_SAMPLE_INSET_PX, max(rowHeight * 0.5 - 0.5, 0.0));
}

vec3 sampleRowEdgePair(float x, float rowBottom, float rowHeight, float inset, out float agreement)
{
    vec3 bottom = sampleSourceCoord(vec2(x, rowBottom + inset));
    vec3 top = sampleSourceCoord(vec2(x, rowBottom + rowHeight - inset));
    agreement = backgroundSampleAgreement(top, bottom);
    return (top + bottom) * 0.5;
}

vec3 sampleHorizontalCellSidePair(
    float y,
    float leftX,
    float rightX,
    out float agreement,
    out float distance
)
{
    vec3 left = sampleSourceCoord(vec2(leftX, y));
    vec3 right = sampleSourceCoord(vec2(rightX, y));
    distance = colorDistance(left, right);
    agreement = 1.0 - smoothstep(
        CELL_BG_AGREE_MIN_DELTA,
        CELL_BG_AGREE_MAX_DELTA,
        distance
    );
    return (left + right) * 0.5;
}

// Estimate the cell-local app background using only samples from the current
// cell. First prefer agreeing left/right margin edge pairs, which avoids using
// neighboring cells across hard background boundaries. If both row edges are
// partially contaminated by glyphs, look for a clean single edge that also
// agrees with a second sample farther inside the cell. Only after those margin
// checks fail do we trust the center top/bottom pair, because glyph bowls,
// descenders, and underlines can make the center probes agree on foreground.
// Split block glyphs can leave no unique answer inside the cell; in that case
// return the source color so both block and empty quadrants stay flat.
vec3 estimateCellBackground(
    vec2 fragCoord,
    vec3 sourceColor,
    float rowHeight,
    float cellWidth,
    float cellOriginX
)
{
    // Use the same row alignment as the gradient itself so the background
    // samples come from the row that controls this pixel's gradient phase.
    float rowBottom = estimatedRowBottom(fragCoord.y, rowHeight);
    float inset = cellBackgroundSampleInset(rowHeight);
    float centerX = estimatedColumnCenterX(fragCoord.x, cellOriginX, cellWidth, 0.0);
    float leftSideX = estimatedColumnSampleX(
        fragCoord.x,
        cellOriginX,
        cellWidth,
        0.0,
        CELL_BG_SIDE_SAMPLE_FRACTION
    );
    float rightSideX = estimatedColumnSampleX(
        fragCoord.x,
        cellOriginX,
        cellWidth,
        0.0,
        1.0 - CELL_BG_SIDE_SAMPLE_FRACTION
    );

    float leftSideAgreement = 0.0;
    vec3 leftSideColor = sampleRowEdgePair(leftSideX, rowBottom, rowHeight, inset, leftSideAgreement);
    float rightSideAgreement = 0.0;
    vec3 rightSideColor = sampleRowEdgePair(rightSideX, rowBottom, rowHeight, inset, rightSideAgreement);
    float sideAgreement = backgroundSampleAgreement(leftSideColor, rightSideColor);

    // Prefer side consensus, which keeps vertical center strokes from being
    // mistaken for the cell background.
    if (
        leftSideAgreement >= CELL_BG_SIDE_MIN_AGREEMENT &&
        rightSideAgreement >= CELL_BG_SIDE_MIN_AGREEMENT &&
        sideAgreement >= CELL_BG_SIDES_MIN_AGREEMENT
    ) {
        return (
            leftSideColor * leftSideAgreement +
            rightSideColor * rightSideAgreement
        ) / (leftSideAgreement + rightSideAgreement);
    }
    if (
        leftSideAgreement >= CELL_BG_SIDE_MIN_AGREEMENT &&
        rightSideAgreement >= CELL_BG_SIDE_MIN_AGREEMENT &&
        colorDistance(leftSideColor, rightSideColor) >= CELL_BG_SPLIT_BLOCK_MIN_DELTA
    ) {
        return sourceColor;
    }

    float innerInset = min(
        inset + CELL_BG_SINGLE_EDGE_INNER_OFFSET_PX,
        max(rowHeight * 0.5 - 0.5, inset)
    );
    float nearEdgeAgreement = 0.0;
    float nearEdgeDistance = 0.0;
    vec3 nearEdgeColor = sampleHorizontalCellSidePair(
        rowBottom + inset,
        leftSideX,
        rightSideX,
        nearEdgeAgreement,
        nearEdgeDistance
    );
    float nearInnerAgreement = 0.0;
    float nearInnerDistance = 0.0;
    vec3 nearInnerColor = sampleHorizontalCellSidePair(
        rowBottom + innerInset,
        leftSideX,
        rightSideX,
        nearInnerAgreement,
        nearInnerDistance
    );
    float nearEdgeCleanAgreement = min(
        min(nearEdgeAgreement, nearInnerAgreement),
        backgroundSampleAgreement(nearEdgeColor, nearInnerColor)
    );

    float farEdgeAgreement = 0.0;
    float farEdgeDistance = 0.0;
    vec3 farEdgeColor = sampleHorizontalCellSidePair(
        rowBottom + rowHeight - inset,
        leftSideX,
        rightSideX,
        farEdgeAgreement,
        farEdgeDistance
    );
    float farInnerAgreement = 0.0;
    float farInnerDistance = 0.0;
    vec3 farInnerColor = sampleHorizontalCellSidePair(
        rowBottom + rowHeight - innerInset,
        leftSideX,
        rightSideX,
        farInnerAgreement,
        farInnerDistance
    );
    float farEdgeCleanAgreement = min(
        min(farEdgeAgreement, farInnerAgreement),
        backgroundSampleAgreement(farEdgeColor, farInnerColor)
    );

    // Underlines can contaminate either row edge. Require a single-edge vote to
    // agree with a second sample farther inside the same cell.
    if (
        nearEdgeCleanAgreement >= CELL_BG_SINGLE_EDGE_MIN_AGREEMENT &&
        farEdgeCleanAgreement >= CELL_BG_SINGLE_EDGE_MIN_AGREEMENT
    ) {
        if (colorDistance(nearEdgeColor, farEdgeColor) >= CELL_BG_SPLIT_BLOCK_MIN_DELTA) {
            return sourceColor;
        }
        return (nearEdgeColor + farEdgeColor) * 0.5;
    }
    if (
        nearEdgeCleanAgreement >= CELL_BG_SINGLE_EDGE_MIN_AGREEMENT &&
        farEdgeDistance >= CELL_BG_SPLIT_BLOCK_MIN_DELTA
    ) {
        return sourceColor;
    }
    if (
        farEdgeCleanAgreement >= CELL_BG_SINGLE_EDGE_MIN_AGREEMENT &&
        nearEdgeDistance >= CELL_BG_SPLIT_BLOCK_MIN_DELTA
    ) {
        return sourceColor;
    }
    if (
        nearEdgeDistance >= CELL_BG_SPLIT_BLOCK_MIN_DELTA &&
        farEdgeDistance >= CELL_BG_SPLIT_BLOCK_MIN_DELTA
    ) {
        return sourceColor;
    }
    if (nearEdgeCleanAgreement >= CELL_BG_SINGLE_EDGE_MIN_AGREEMENT) {
        return nearEdgeColor;
    }
    if (farEdgeCleanAgreement >= CELL_BG_SINGLE_EDGE_MIN_AGREEMENT) {
        return farEdgeColor;
    }

    float centerAgreement = 0.0;
    vec3 centerColor = sampleRowEdgePair(centerX, rowBottom, rowHeight, inset, centerAgreement);

    if (centerAgreement >= CELL_BG_CENTER_MIN_AGREEMENT) {
        return centerColor;
    }

    if (leftSideAgreement >= CELL_BG_SIDE_MIN_AGREEMENT) {
        return leftSideColor;
    }
    if (rightSideAgreement >= CELL_BG_SIDE_MIN_AGREEMENT) {
        return rightSideColor;
    }
    return iBackgroundColor;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 source = texture(iChannel0, uv);
    vec4 sourceWithShadow = source;
    if (SHADOW_STRENGTH > 0.0) {
        sourceWithShadow = applyTextShadow(fragCoord, source);
    }
    if (GRADIENT_STRENGTH <= 0.0 && SHINE_STRENGTH <= 0.0) {
        fragColor = sourceWithShadow;
        return;
    }

    // Underline/bar cursor modes can be much shorter than block mode. Use the
    // larger previous/current cursor height so the row gradient does not get
    // squished during cursor mode changes.
    float cursorHeight = max(iPreviousCursor.w, iCurrentCursor.w);
    float rowHeight = max(cursorHeight, 1.0);
    float cursorWidth = max(iPreviousCursor.z, iCurrentCursor.z);
    float cellWidth = max(cursorWidth, 1.0);

    // Estimate the active cell/app background before deciding whether this
    // source pixel is text. This handles TUIs that paint their own background.
    vec3 background = estimateCellBackground(fragCoord.xy, source.rgb, rowHeight, cellWidth, iCurrentCursor.x);
    float text = textMask(source.rgb, background);
    if (text <= 0.0) {
        fragColor = sourceWithShadow;
        return;
    }
    if (!shouldTreatText(source.rgb, background)) {
        fragColor = sourceWithShadow;
        return;
    }

    vec4 color = sourceWithShadow;

    if (GRADIENT_STRENGTH > 0.0) {
        float rowPhase = fract((fragCoord.y + GRADIENT_Y_OFFSET_PX) / rowHeight);
        float rowPosition = 1.0 - rowPhase;
        float seamWidth = min(GRADIENT_ROW_SEAM_SMOOTH_PX / rowHeight, 0.5);
        // Feather row starts so underline spillover does not jump to full brightness.
        rowPosition *= smoothstep(0.0, seamWidth, rowPhase);
        float gradientPosition = smoothstep(
            GRADIENT_START,
            GRADIENT_STOP,
            rowPosition
        );
        // Scale the gradient strength using the contrast between current pixel color and background color.
        float contrastScale = gradientContrastFromBackground(source.rgb, background);
        if (contrastScale > 0.0) {
            float gradientStrength = GRADIENT_STRENGTH * contrastScale;
            float gradientBrightness = mix(1.0 - gradientStrength, 1.0 + gradientStrength, gradientPosition);

            vec4 gradientColor = applyOkLabBrightness(color, gradientBrightness);
            color = mix(color, gradientColor, text);
        }
    }

    if (SHINE_STRENGTH > 0.0) {
        float shineMask = 0.0;
        for (int i = 0; i < 2; i++) {
            shineMask += (
                shineLayerMask(uv, background, text, SHINE_LAYER_SPREADS[i]) *
                SHINE_LAYER_WEIGHTS[i]
            );
        }
        shineMask = smoothstep(0.0, 1.0, shineMask);

        // Favor stronger shine on clearly text-like pixels with enough contrast to
        // carry the effect cleanly.
        float contrastScale = shineContrastFromBackground(source.rgb, background);
        float shineTextStrength = smoothstep(0.55, 1.0, text);
        float shineLift = shineMask * SHINE_STRENGTH * shineTextStrength * contrastScale;
        float shineCompensation = text * SHINE_BALANCE;
        float shineBrightness = 1.0 + shineLift - shineCompensation;
        color = applyOkLabBrightness(color, shineBrightness);
    }

    fragColor = color;
}
