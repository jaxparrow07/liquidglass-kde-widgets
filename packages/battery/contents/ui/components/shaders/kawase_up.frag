#version 440

// Dual Kawase upsample — 9 taps.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  halfpixel;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;

    vec4 sum = texture(source, uv + vec2(-halfpixel.x * 2.0, 0.0));
    sum += texture(source, uv + vec2(-halfpixel.x, halfpixel.y)) * 2.0;
    sum += texture(source, uv + vec2(0.0, halfpixel.y * 2.0));
    sum += texture(source, uv + vec2(halfpixel.x, halfpixel.y)) * 2.0;
    sum += texture(source, uv + vec2(halfpixel.x * 2.0, 0.0));
    sum += texture(source, uv + vec2(halfpixel.x, -halfpixel.y)) * 2.0;
    sum += texture(source, uv + vec2(0.0, -halfpixel.y * 2.0));
    sum += texture(source, uv + vec2(-halfpixel.x, -halfpixel.y)) * 2.0;

    fragColor = sum / 12.0 * qt_Opacity;
}
