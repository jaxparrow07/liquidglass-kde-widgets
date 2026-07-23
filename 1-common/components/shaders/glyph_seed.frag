#version 440

// JFA seed pass for text-shaped liquid glass.
//
// Input `mask` is the rendered glyph coverage (white-on-transparent text,
// alpha = coverage). We seed the Jump-Flood with EDGE texels — those that
// sit on the inside/outside boundary of the glyph silhouette (coverage
// straddles 0.5 across a 1-texel neighbourhood). Each seed stores its own
// UV; non-seed texels store a sentinel.
//
// Output encoding (matches jfa.frag / glyph_sdf.frag):
//   rg = nearest seed UV in [0,1]   (this texel's own UV when it is a seed)
//   b  = 1.0 when a seed is recorded, 0.0 otherwise (validity flag)
//   a  = this texel's own coverage (carried through so glyph_sdf can sign d)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  texel;   // 1.0 / textureSize, in UV units
};

layout(binding = 1) uniform sampler2D mask;

float cov(vec2 uv) { return texture(mask, clamp(uv, vec2(0.0), vec2(1.0))).a; }

void main() {
    vec2 uv = qt_TexCoord0;
    float c = cov(uv);

    // 4-neighbour edge test: this texel is on the contour if its coverage
    // and a cardinal neighbour's coverage land on opposite sides of 0.5.
    float l = cov(uv + vec2(-texel.x, 0.0));
    float r = cov(uv + vec2( texel.x, 0.0));
    float u = cov(uv + vec2(0.0, -texel.y));
    float d = cov(uv + vec2(0.0,  texel.y));

    bool inside = c > 0.5;
    bool isEdge = (inside != (l > 0.5)) || (inside != (r > 0.5))
               || (inside != (u > 0.5)) || (inside != (d > 0.5));

    if (isEdge) {
        fragColor = vec4(uv, 1.0, c);
    } else {
        fragColor = vec4(0.0, 0.0, 0.0, c);
    }
}
