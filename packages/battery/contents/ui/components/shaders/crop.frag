#version 440

// Crop shader: maps widget-local UV to wallpaper UV and samples.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  uvOffset;
    vec2  uvScale;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 wpUV = clamp(uvOffset + qt_TexCoord0 * uvScale, vec2(0.0), vec2(1.0));
    fragColor = texture(source, wpUV) * qt_Opacity;
}
