#version 440

// One Jump-Flood Algorithm pass. Run ping-pong between two
// ShaderEffectSources with `step` halving each pass (… 16, 8, 4, 2, 1 px,
// expressed in UV) to propagate the nearest seed UV recorded by
// glyph_seed.frag across the whole texture.
//
// Encoding (in/out):
//   rg = best (nearest) seed UV so far
//   b  = validity flag (1 = rg holds a real seed)
//   a  = this texel's own coverage (carried through untouched)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  step;    // jump distance this pass, in UV units
};

layout(binding = 1) uniform sampler2D src;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 self = texture(src, uv);

    vec2 best = self.rg;
    float haveBest = self.b;
    // Distance to current best (large if none yet).
    float bestDist = haveBest > 0.5 ? distance(uv, best) : 1e9;

    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            if (i == 0 && j == 0) continue;
            vec2 suv = uv + vec2(float(i), float(j)) * step;
            vec4 s = texture(src, clamp(suv, vec2(0.0), vec2(1.0)));
            if (s.b > 0.5) {
                float dd = distance(uv, s.rg);
                if (dd < bestDist) {
                    bestDist = dd;
                    best = s.rg;
                    haveBest = 1.0;
                }
            }
        }
    }

    fragColor = vec4(best, haveBest, self.a);
}
