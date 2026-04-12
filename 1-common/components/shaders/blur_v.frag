#version 440

// Vertical gaussian blur — mirror of blur_h along Y.

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

    float stepUV = radiusPx / sourceSizePx.y / 4.0;

    const float w0 = 0.19741;
    const float w1 = 0.17466;
    const float w2 = 0.12099;
    const float w3 = 0.06560;
    const float w4 = 0.02783;

    vec4 c = texture(source, uv) * w0;

    c += texture(source, uv + vec2(0.0, stepUV * 1.0)) * w1;
    c += texture(source, uv - vec2(0.0, stepUV * 1.0)) * w1;

    c += texture(source, uv + vec2(0.0, stepUV * 2.0)) * w2;
    c += texture(source, uv - vec2(0.0, stepUV * 2.0)) * w2;

    c += texture(source, uv + vec2(0.0, stepUV * 3.0)) * w3;
    c += texture(source, uv - vec2(0.0, stepUV * 3.0)) * w3;

    c += texture(source, uv + vec2(0.0, stepUV * 4.0)) * w4;
    c += texture(source, uv - vec2(0.0, stepUV * 4.0)) * w4;

    c /= (w0 + 2.0 * (w1 + w2 + w3 + w4));

    fragColor = c * qt_Opacity;
}
