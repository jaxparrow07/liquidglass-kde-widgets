#version 440

// Liquid-glass fragment shader — Snell-on-a-dome refraction.
//
// Ported from iyinchao/liquid-glass-studio's fragment-main.glsl.
// Key ideas:
//   * Edge refraction uses Snell's law through a dome-shaped bevel:
//         sinθI = (1 - t)^2      where t = 0..1 across the edge band
//         θT    = asin(sinθI / IOR)
//         mag   = tan(θI - θT)   // lateral shift of the refracted ray
//     That (1-t)^2 term is what gives the "curved glass lens" look
//     vs. a linear ramp.
//   * SDF gradient is kept UNNORMALIZED; its magnitude naturally falls off
//     at corners and acts as a built-in AA gate.
//   * Chromatic dispersion: same refraction vector, different magnitudes
//     per channel via per-channel IOR (R=1+k, G=1, B=1-k).
//
// qt_TexCoord0 is widget-local UV (0..1).
// uvOffset/uvScale map widget UV into the wallpaper texture's UV space.
// `backdrop` is the wallpaper ShaderEffectSource (blur currently disabled).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;              // widget size in px
    float radius;            // corner radius in px
    float refractThickness;  // edge band width in px
    float refractIOR;        // index of refraction, e.g. 1.4
    float refractScale;      // global multiplier on Snell displacement
    float chromaStrength;    // 0..1 chromatic aberration
    vec4  tint;
    vec2  uvOffset;
    vec2  uvScale;
};

layout(binding = 1) uniform sampler2D backdrop;

// --- Shape SDF: rounded rect (plain, not squircle — keeps it simple) ---

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Evaluate SDF at widget-pixel coordinate p.
float sceneSDF(vec2 p) {
    vec2 b = size * 0.5;
    return sdRoundRect(p, b, radius);
}

// Numerical gradient of the SDF. Intentionally NOT normalized — its
// magnitude collapses at the corners and is used downstream as an AA gate.
vec2 sceneGradient(vec2 p) {
    float dx = sceneSDF(p + vec2(1.0, 0.0)) - sceneSDF(p - vec2(1.0, 0.0));
    float dy = sceneSDF(p + vec2(0.0, 1.0)) - sceneSDF(p - vec2(0.0, 1.0));
    return vec2(dx, dy);
}

// Sample the backdrop at a widget-local UV (0..1), mapping through
// uvOffset/uvScale into wallpaper UV space.
vec3 sampleBackdrop(vec2 localUV) {
    vec2 wpUV = clamp(uvOffset + localUV * uvScale, vec2(0.0), vec2(1.0));
    return texture(backdrop, wpUV).rgb;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p  = (uv - vec2(0.5)) * size;      // pixel-space centered
    float d = sceneSDF(p);

    // Outside the shape: fully transparent.
    if (d > 0.5) {
        fragColor = vec4(0.0);
        return;
    }

    // Depth INTO the shape, in pixels. 0 at the border, grows toward center.
    float depthPx = -d;

    // Outside the edge band: flat glass, no refraction.
    if (depthPx >= refractThickness) {
        vec3 col = sampleBackdrop(uv);
        col = mix(col, tint.rgb, tint.a);

        // Final AA: blend to raw background right at the silhouette.
        float mask = 1.0 - smoothstep(-1.0, 0.0, d);
        fragColor = vec4(col, mask) * qt_Opacity;
        return;
    }

    // --- Edge band: Snell on a dome ---

    // t = 0 right at the outer edge, 1 at the band's inner boundary
    float t = depthPx / refractThickness;

    // sinθI follows a curved bevel: (1-t)^2 means the surface rises
    // steeply right at the edge and flattens by the inner boundary.
    float sinThetaI = (1.0 - t) * (1.0 - t);
    float thetaI = asin(clamp(sinThetaI, 0.0, 1.0));

    // Snell: n1 sinθI = n2 sinθT, n1=1 (air), n2=refractIOR
    float sinThetaT = sinThetaI / refractIOR;
    float thetaT = asin(clamp(sinThetaT, 0.0, 1.0));

    // Lateral shift magnitude of the refracted ray, per unit of the
    // normal direction. Positive value pulls the sampled point inward,
    // which is what produces the "magnifying glass lip".
    float edgeMag = tan(thetaI - thetaT);

    // Unit direction along the outward surface normal. We use the unit
    // vector for the refraction direction (so strength is controlled
    // purely by edgeMag + refractScale), and use the raw gradient's
    // magnitude separately as a corner-AA gate.
    vec2 grad = sceneGradient(p);
    float gradLen = length(grad);
    vec2 ndir = gradLen > 1e-4 ? grad / gradLen : vec2(0.0);

    // Displacement in widget pixels -> UV by dividing by size.
    // refractScale is a user-facing strength knob; 40 is a good default
    // for this coordinate system (widget-pixel SDF, not normalized).
    vec2 displacePx = -ndir * edgeMag * refractScale;
    vec2 displaceUV = displacePx / size;

    // Chromatic aberration: R and B sampled at an extra offset along
    // the refraction direction, INDEPENDENT of the Snell magnitude so
    // the dispersion stays visible at both ends of the edge band. The
    // offset grows with how far we are into the band so the center is
    // clean and the edge fringe is strongest.
    //   edgeWeight: 0 at inner boundary (t=1), 1 right at the outer edge (t=0)
    float edgeWeight = 1.0 - t;
    float chromaPx = chromaStrength * refractThickness * 0.35 * edgeWeight;
    vec2 chromaUV = -ndir * chromaPx / size;

    vec3 col;
    col.r = sampleBackdrop(uv + displaceUV + chromaUV).r;
    col.g = sampleBackdrop(uv + displaceUV).g;
    col.b = sampleBackdrop(uv + displaceUV - chromaUV).b;

    // Tint
    col = mix(col, tint.rgb, tint.a);

    // Final AA mask at the silhouette — a narrow smoothstep across d=0.
    float mask = 1.0 - smoothstep(-1.0, 0.0, d);

    fragColor = vec4(col, mask) * qt_Opacity;
}
