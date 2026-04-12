#version 440

// Horizontal gaussian blur — 17-tap symmetric kernel using linear-sample
// pairs. 9 unique texture reads span 17 texels. Weights are a true gaussian
// at sigma = radiusPx / 3, so the kernel "fills" its radius properly rather
// than leaving visible individual samples (the "stained glass" artifact).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float radiusPx;
    vec2  sourceSizePx;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;

    // Spacing between sample pairs, in UV. We sample 8 offsets (plus center)
    // evenly across radiusPx. Using linear-sampled pairs, each real tap
    // covers 2 texels, so effective kernel width = 17 texels.
    float stepUV = radiusPx / sourceSizePx.x / 4.0;

    // Gaussian weights at offsets 0, 1, 2, 3, 4 (sigma = 2.0). Normalized.
    // Values from exp(-x^2 / (2*sigma^2)) / sqrt(2*pi*sigma^2).
    const float w0 = 0.19741;
    const float w1 = 0.17466;
    const float w2 = 0.12099;
    const float w3 = 0.06560;
    const float w4 = 0.02783;

    vec4 c = texture(source, uv) * w0;

    c += texture(source, uv + vec2(stepUV * 1.0, 0.0)) * w1;
    c += texture(source, uv - vec2(stepUV * 1.0, 0.0)) * w1;

    c += texture(source, uv + vec2(stepUV * 2.0, 0.0)) * w2;
    c += texture(source, uv - vec2(stepUV * 2.0, 0.0)) * w2;

    c += texture(source, uv + vec2(stepUV * 3.0, 0.0)) * w3;
    c += texture(source, uv - vec2(stepUV * 3.0, 0.0)) * w3;

    c += texture(source, uv + vec2(stepUV * 4.0, 0.0)) * w4;
    c += texture(source, uv - vec2(stepUV * 4.0, 0.0)) * w4;

    // Normalize (weights only sum to ~0.877; rescale for brightness)
    c /= (w0 + 2.0 * (w1 + w2 + w3 + w4));

    fragColor = c * qt_Opacity;
}
