/*
 * Adds a per-row vertical gradient to text using the current cursor height:
 * darker near the bottom of each row and lighter near the top.
 */

// Since Ghostty doesn't expose terminal cell dimensions, we estimate it using
// the cursor height. This shifts where the gradient starts within rows.
const float GRADIENT_Y_OFFSET_PX = -4.0;

// Set to 0.0 to disable the gradient completely.
const float GRADIENT_STRENGTH = 0.3;

// Defines the minimum contrast from the bg needed to get any gradient treatment.
const float GRADIENT_STRENGTH_SCALING_MIN_CONTRAST = 0.1;
// Defines how much contrast from the bg is needed to get a full-strength gradient.
const float GRADIENT_STRENGTH_SCALING_MAX_CONTRAST = 0.5;

// Gradient is a linear gradient going from the bottom of the row to the top (0-1).
// Adjust the start/stop values to condense the gradient. Swap them to reverse the gradient.
const float GRADIENT_START = 0.0;
const float GRADIENT_STOP  = 1.0;

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


// sRGB linear -> nonlinear transform from https://bottosson.github.io/posts/colorwrong/
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

float contrastFromBackground(vec3 color, vec3 background)
{
    vec3 diff = abs(color - background);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = abs(luminance(color) - luminance(background));
    return smoothstep(
        GRADIENT_STRENGTH_SCALING_MIN_CONTRAST,
        GRADIENT_STRENGTH_SCALING_MAX_CONTRAST,
        max(channelDelta, colorDelta)
    );
}

vec3 sampleSourceCoord(vec2 coord)
{
    vec2 uv = clamp(coord / iResolution.xy, vec2(0.0), vec2(1.0));
    return texture(iChannel0, uv).rgb;
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
    if (GRADIENT_STRENGTH <= 0.0) {
        fragColor = source;
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
        fragColor = source;
        return;
    }

    float rowPosition = 1.0 - fract((fragCoord.y + GRADIENT_Y_OFFSET_PX) / rowHeight);
    float gradientPosition = smoothstep(
        GRADIENT_START,
        GRADIENT_STOP,
        rowPosition
    );
    // Scale the gradient strength using the contrast between current pixel color and background color.
    float contrastScale = contrastFromBackground(source.rgb, background);
    if (contrastScale <= 0.0) {
        fragColor = source;
        return;
    }
    float gradientStrength = GRADIENT_STRENGTH * contrastScale;
    float gradientBrightness = mix(1.0 - gradientStrength, 1.0 + gradientStrength, gradientPosition);

    vec4 gradientColor = applyOkLabBrightness(source, gradientBrightness);
    vec4 color = mix(source, gradientColor, text);

    fragColor = color;
}
