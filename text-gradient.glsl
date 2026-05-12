/*
 * Adds a per-row vertical gradient to text using the current cursor height:
 * darker near the bottom of each row and lighter near the top.
 */

// Set to 0.0 to disable the gradient completely.
const float GRADIENT_STRENGTH = 0.3;

// If you want to reduce the overall strength of the gradient based on how dim
// the text is, you can set the contrast thresholds for the strength scaling.
// Set MIN to 1.0 or MAX to 0.0 to disable strength scaling.

// Defines the minimum contrast from the bg needed to get any gradient treatment.
const float GRADIENT_STRENGTH_SCALING_MIN_CONTRAST = 0.05;

// Defines how much contrast from the bg is needed to get a full-strength gradient.
const float GRADIENT_STRENGTH_SCALING_MAX_CONTRAST = 0.5;

// The position where the gradient reaches min brightness.
// 0.0 = top of row, 1.0 = bottom of row
// Swap the start/stop values to reverse the gradient.
const float GRADIENT_START = 0.1;

// The position where the gradient reaches max darkness.
const float GRADIENT_STOP  = 0.9;

// Since Ghostty doesn't expose terminal cell dimensions, we estimate it using
// the cursor height. This shifts where the gradient starts within rows.
const float GRADIENT_Y_OFFSET_PX = -4.0;


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
        GRADIENT_STRENGTH_SCALING_MIN_CONTRAST,
        GRADIENT_STRENGTH_SCALING_MAX_CONTRAST,
        contrast
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);
    float text = textMask(color.rgb);

    // Underline/bar cursor modes can be much shorter than block mode. Use the
    // larger previous/current cursor height so the row gradient does not get
    // squished during cursor mode changes.
    float cursorHeight = max(iPreviousCursor.w, iCurrentCursor.w);
    float rowHeight = max(cursorHeight, 1.0);
    float rowPosition = 1.0 - fract((fragCoord.y + GRADIENT_Y_OFFSET_PX) / rowHeight);
    float gradientPosition = smoothstep(
        GRADIENT_START,
        GRADIENT_STOP,
        rowPosition
    );
    // Scale the gradient strength using the contrast between current pixel color and background color.
    float contrastScale = contrastFromBackground(color.rgb);
    float gradientStrength = GRADIENT_STRENGTH * contrastScale;
    float gradientBrightness = mix(1.0 - gradientStrength, 1.0 + gradientStrength, gradientPosition);
    color.rgb = mix(color.rgb, clamp(color.rgb * gradientBrightness, 0.0, 1.0), text);

    fragColor = color;
}
