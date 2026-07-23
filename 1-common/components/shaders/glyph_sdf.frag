#version 440

// Resolve a glyph signed distance field + edge normal into the texture the
// text-glass shader samples. Two source modes:
//
//   fastSDF == 0  (accurate / realtime OFF): `src` is the resolved Jump-Flood
//                 texture (rg = nearest contour UV, a = coverage). Distance is
//                 the exact euclidean distance to the nearest contour texel;
//                 normal points from the contour toward this texel.
//
//   fastSDF == 1  (fast / realtime ON): `src` is a blurred coverage ramp
//                 (a = blurred coverage, ~0.5 at the contour). Distance is
//                 approximated from the ramp value; normal from its gradient.
//
// Output encoding (read by liquidglasstext.frag):
//   rg = unit edge normal mapped [-1,1] -> [0,1] (points OUT of the glyph)
//   b  = signed distance packed: 0.5 + clamp(d/sdfRange, -1, 1) * 0.5
//        (d < 0 inside the glyph, d > 0 outside; px units)
//   a  = coverage (1 inside, 0 outside) for solid-mode fill + AA

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;       // widget size in px (UV -> px conversion)
    vec2  texel;      // 1.0 / textureSize, UV units
    float sdfRange;   // px span packed into b channel (= max usable |d|)
    float fastSDF;    // 0 = JFA exact, 1 = blurred-ramp approximation
    float rampScale;  // px-per-coverage-unit for the fast ramp -> distance
    float gradStepPx; // sample offset (px) for the fast-ramp normal gradient
};

layout(binding = 1) uniform sampler2D src;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 s = texture(src, uv);

    float dPx;       // signed distance in px (negative inside)
    vec2  nrm;       // unit outward normal
    float coverage;

    if (fastSDF < 0.5) {
        // --- Accurate: nearest-contour from JFA ---
        coverage = s.a;
        float inside = coverage > 0.5 ? 1.0 : 0.0;
        vec2 nearestUV = s.rg;
        bool haveSeed = s.b > 0.5;

        vec2 toEdgePx = (uv - nearestUV) * size;   // texel -> contour vector
        float distPx = haveSeed ? length(toEdgePx) : sdfRange;

        // Outward normal: from contour toward outside. Inside texels point
        // back the other way, so flip by inside-ness.
        vec2 dir = distPx > 1e-4 ? normalize(toEdgePx) : vec2(0.0, -1.0);
        nrm = (inside > 0.5) ? -dir : dir;

        dPx = (inside > 0.5) ? -distPx : distPx;
    } else {
        // --- Fast: blurred coverage ramp ---
        float c = s.a;
        coverage = c;
        // Ramp crosses 0.5 at the contour; convert to a signed distance.
        dPx = (0.5 - c) * rampScale;

        // Normal = direction of decreasing coverage (toward outside).
        //
        // Sampled with a Sobel 3x3 kernel at a multi-px offset rather than a
        // 1-texel central difference. On tight inner curves (the bowls of 3/8,
        // the holes of 8) opposing blurred edges crowd together, so a 1-texel
        // gradient is noisy and points the wrong way -> refraction artifacts.
        // The wider Sobel stencil reads the true slope direction and averages
        // out that noise.
        vec2 o = texel * max(gradStepPx, 1.0);
        float tl = texture(src, uv + vec2(-o.x, -o.y)).a;
        float tc = texture(src, uv + vec2( 0.0, -o.y)).a;
        float tr = texture(src, uv + vec2( o.x, -o.y)).a;
        float ml = texture(src, uv + vec2(-o.x,  0.0)).a;
        float mr = texture(src, uv + vec2( o.x,  0.0)).a;
        float bl = texture(src, uv + vec2(-o.x,  o.y)).a;
        float bc = texture(src, uv + vec2( 0.0,  o.y)).a;
        float br = texture(src, uv + vec2( o.x,  o.y)).a;

        float cx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
        float cy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
        vec2 g = vec2(-cx, -cy);   // up the gradient is INTO the glyph; negate

        // Dead-zone: in the deep interior the coverage plateaus (gradient ~0);
        // a normal there is meaningless, but those fragments are past the
        // refraction band anyway, so default to a stable up-normal.
        nrm = length(g) > 1e-3 ? normalize(g) : vec2(0.0, -1.0);
    }

    float packedD = 0.5 + clamp(dPx / max(sdfRange, 1.0), -1.0, 1.0) * 0.5;
    vec2 packedN = nrm * 0.5 + vec2(0.5);

    fragColor = vec4(packedN, packedD, coverage);
}
