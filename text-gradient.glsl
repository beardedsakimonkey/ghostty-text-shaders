/*
 * Adds a per-row vertical gradient to text using the current cursor height:
 * darker near the bottom of each row and lighter near the top.
 */

// Set to 0.0 to disable the gradient completely.
const float GRADIENT_STRENGTH = 0.4;

// If you want to reduce the overall strength of the gradient based on how dim
// the text is, you can set the contrast thresholds for the strength scaling.
// Set MIN to 1.0 or MAX to 0.0 to disable strength scaling.

// Defines the minimum contrast from the bg needed to get any gradient treatment.
const float GRADIENT_STRENGTH_SCALING_MIN_CONTRAST = 0.1;

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


float luminance(vec3 color)
{
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float textMask(vec3 color)
{
    vec3 diff = abs(color - iBackgroundColor);
    float channelDelta = max(max(diff.r, diff.g), diff.b);
    float colorDelta = abs(luminance(color) - luminance(iBackgroundColor));
    return smoothstep(0.01, 0.1, max(channelDelta, colorDelta));
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

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 source = texture(iChannel0, uv);
    float text = textMask(source.rgb);

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
    float contrastScale = contrastFromBackground(source.rgb);
    float gradientStrength = GRADIENT_STRENGTH * contrastScale;
    float gradientBrightness = mix(1.0 - gradientStrength, 1.0 + gradientStrength, gradientPosition);

    vec4 gradientColor = applyOkLabBrightness(source, gradientBrightness);
    vec4 color = mix(source, gradientColor, text);

    fragColor = color;
}
