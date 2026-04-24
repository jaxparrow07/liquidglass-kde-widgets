#version 440

// Liquid-glass fragment shader — Snell-on-a-dome refraction + corner specular.
//
// Ported from iyinchao/liquid-glass-studio's fragment-main.glsl with extras.
// Key ideas:
//   * Edge refraction uses Snell's law through a dome-shaped bevel:
//         sinθI = (1 - t)^2      where t = 0..1 across the edge band
//         θT    = asin(sinθI / IOR)
//         mag   = tan(θI - θT)   // lateral shift of the refracted ray
//   * SDF gradient is kept UNNORMALIZED and its magnitude is reused as a
//     corner-AA gate.
//   * Chromatic dispersion: R/B sampled at an extra offset along the
//     refraction direction, scaled by how deep we are in the edge band.
//   * Corner specular: on hover, the two corners on the diagonal nearest
//     the cursor light up; brightness tapers exponentially along the
//     border from each apex; applied on the outer lip only.
//
// qt_TexCoord0 is widget-local UV (0..1).
// uvOffset/uvScale map widget UV -> wallpaper UV.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;              // widget size in px
    float radius;            // corner radius in px
    float roundness;         // superellipse exponent; 2 = circle, 5 ≈ iOS squircle
    float refractThickness;  // edge band width in px
    float refractIOR;
    float refractScale;
    float chromaStrength;    // 0..1 chromatic aberration
    vec4  tint;
    vec2  uvOffset;
    vec2  uvScale;
    vec2  mousePos;          // widget-local UV (0..1); (-1,-1) = no mouse
    float mouseFade;         // 0..1 hover fade
    float specStrength;      // 0..1 intensity
};

layout(binding = 1) uniform sampler2D backdrop;

// --- Shape SDF: superellipse-cornered rounded rect (squircle) ---

// Squircle / rounded-box SDF with analytic gradient.
//
// Returns vec3(d, nx, ny) where (nx, ny) is the unit outward normal.
//
//   q     = |p| - b + r
//   arc   = (qx^n + qy^n)^(1/n)   — qx = max(q.x, 0), qy = max(q.y, 0)
//   d_rel = min(max(q.x, q.y), 0) + arc - r
//   d     = d_rel / |∇|           — normalize to unit-gradient distance
//
// Fast paths:
//   * Interior (qx == 0 && qy == 0): level-set slope is 1 from the
//     min/max term; no pow() needed.
//   * Straight edge (exactly one of qx/qy is zero): p-norm collapses to
//     |q.x| or |q.y|; gradient is axis-aligned; no pow() needed.
//   * Corner wedge (both qx > 0 && qy > 0): p-norm and analytic
//     gradient.
//
// Sign convention: normal flipped by sign(p) at return time so it
// points outward in original p-space (q uses abs(p)).
vec3 sceneSDFAndNormal(vec2 p) {
    vec2 b = size * 0.5;
    float r = radius;
    float n = roundness;

    vec2 q = abs(p) - b + vec2(r);
    float qx = max(q.x, 0.0);
    float qy = max(q.y, 0.0);

    float d;
    vec2 nrm;

    if (qx <= 0.0 && qy <= 0.0) {
        // Interior: nearest silhouette is the straight edge. Level-set
        // slope is 1 already; normal is the axis with the larger q.
        d = max(q.x, q.y) - r;
        nrm = q.x >= q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    } else if (qx == 0.0) {
        // Top/bottom straight edge past the corner box.
        d = qy - r;
        nrm = vec2(0.0, 1.0);
    } else if (qy == 0.0) {
        // Left/right straight edge past the corner box.
        d = qx - r;
        nrm = vec2(1.0, 0.0);
    } else {
        // Corner wedge: both qx, qy > 0.
        float qxn = pow(qx, n);
        float qyn = pow(qy, n);
        float arc = pow(qxn + qyn, 1.0 / n);
        // ∂arc/∂x = (qx/arc)^(n-1); same for y.
        float gx = pow(qx / arc, n - 1.0);
        float gy = pow(qy / arc, n - 1.0);
        float gradLen = sqrt(gx*gx + gy*gy);
        d   = (arc - r) / max(gradLen, 1e-3);
        nrm = vec2(gx, gy) / max(gradLen, 1e-3);
    }

    // q uses abs(p); flip the normal back to original-space signs.
    nrm *= sign(p + vec2(1e-20));
    return vec3(d, nrm);
}

// Distance-only helper for the silhouette mask / outside test.
float sceneSDF(vec2 p) {
    return sceneSDFAndNormal(p).x;
}

vec3 sampleBackdrop(vec2 localUV) {
    vec2 wpUV = clamp(uvOffset + localUV * uvScale, vec2(0.0), vec2(1.0));
    return texture(backdrop, wpUV).rgb;
}

// Corner border specular. Always visible (even without hover) as a
// thin stroke on two diagonal corners. Hover rotates the diagonal to
// follow the cursor. Prominence: dominant corner full, diagonal
// opposite half, the other two minimal. Slight feather.
vec3 cornerSpec(vec2 p, float depthPx) {
    if (specStrength <= 0.0) return vec3(0.0);

    // Hard cap on stroke thickness at the dominant apex, in px.
    const float MAX_STROKE_PX = 3.0;
    const float DOMINANT     = 1.0;  // the single dominant corner
    const float DIAGONAL     = 0.5;  // its diagonal opposite
    const float OTHER        = 0.0;  // the other two corners (off)

    vec2 b = size * 0.5;

    // Corner apexes (outer-rectangle corners).
    vec2 aTL = vec2(-b.x,  b.y);
    vec2 aTR = vec2( b.x,  b.y);
    vec2 aBL = vec2(-b.x, -b.y);
    vec2 aBR = vec2( b.x, -b.y);

    // Virtual "light" position that drives the softmax dominance.
    // At rest (mouseFade=0): park it just outside TL so the TL+BR
    // diagonal is the default lit pair. On hover: smoothly blend toward
    // the real cursor so the diagonal rotates to follow it.
    vec2 restLight = aTL * 1.2;
    bool hovering  = mouseFade > 0.0 && mousePos.x >= 0.0 && mousePos.y >= 0.0;
    vec2 cursorPx  = (mousePos - vec2(0.5)) * size;
    vec2 lightPx   = hovering ? mix(restLight, cursorPx, mouseFade) : restLight;

    // Distances from each corner to the virtual light.
    float dTL = distance(lightPx, aTL);
    float dTR = distance(lightPx, aTR);
    float dBL = distance(lightPx, aBL);
    float dBR = distance(lightPx, aBR);

    // Diagonal selection: TL+BR vs TR+BL. Use min-distance within each
    // pair so the diagonal containing the closest corner wins. Smooth
    // crossover with a softmax so there's no hard pop on the axis.
    float diag1Near = min(dTL, dBR);  // TL+BR
    float diag2Near = min(dTR, dBL);  // TR+BL
    float diagSharp = 1.0 / (max(size.x, size.y) * 0.12);
    float wD1 = exp(-diag1Near * diagSharp);
    float wD2 = exp(-diag2Near * diagSharp);
    float wDsum = wD1 + wD2 + 1e-6;
    wD1 /= wDsum; wD2 /= wDsum;

    // Within each diagonal, whichever corner is closer to the light
    // gets DOMINANT, the other gets DIAGONAL.
    float d1_TL_role = (dTL <= dBR) ? DOMINANT : DIAGONAL;
    float d1_BR_role = (dTL <= dBR) ? DIAGONAL : DOMINANT;
    float d2_TR_role = (dTR <= dBL) ? DOMINANT : DIAGONAL;
    float d2_BL_role = (dTR <= dBL) ? DIAGONAL : DOMINANT;

    // Per-corner prominence: role from its diagonal, weighted by that
    // diagonal's softmax weight. Corners on the losing diagonal get 0.
    float promTL = wD1 * d1_TL_role;
    float promBR = wD1 * d1_BR_role;
    float promTR = wD2 * d2_TR_role;
    float promBL = wD2 * d2_BL_role;

    // Arc-length attenuation along the border from each apex.
    // Taper scales with widget size so the stroke reads the same
    // at 150px and 500px widgets.
    float taper = max(size.x, size.y) * 0.7;
    float aTLa = exp(-distance(p, aTL) / taper);
    float aTRa = exp(-distance(p, aTR) / taper);
    float aBLa = exp(-distance(p, aBL) / taper);
    float aBRa = exp(-distance(p, aBR) / taper);

    // Effective stroke thickness at this fragment. Take the max so
    // contributions don't double up.
    float tPx = 0.0;
    tPx = max(tPx, promTL * aTLa * MAX_STROKE_PX);
    tPx = max(tPx, promTR * aTRa * MAX_STROKE_PX);
    tPx = max(tPx, promBL * aBLa * MAX_STROKE_PX);
    tPx = max(tPx, promBR * aBRa * MAX_STROKE_PX);

    // Render the stroke with a 2px feather on the inner lip so it
    // reads as a softened hairline rather than a hard slab.
    const float FEATHER_PX = 2.0;
    float stroke = 1.0 - smoothstep(tPx - FEATHER_PX, tPx, depthPx);

    // Global tone-down multiplier so the effect stays subtle even at
    // specStrength = 1.0.
    float I = stroke * specStrength * 0.55;
    return vec3(1.0, 0.98, 0.94) * I;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p  = (uv - vec2(0.5)) * size;
    vec3 dn = sceneSDFAndNormal(p);
    float d = dn.x;
    vec2 ndir = dn.yz;

    // Outside the shape (past the feather band): fully transparent.
    if (d > 1.5) {
        fragColor = vec4(0.0);
        return;
    }

    vec3 col;
    float depthPx = -d;

    if (depthPx >= refractThickness) {
        // Interior: flat glass (pass-through + tint), no refraction.
        col = sampleBackdrop(uv);
        col = mix(col, tint.rgb, tint.a);
    } else {
        // --- Edge band: Snell on a dome ---
        // Clamp t so fragments in the outer feather band (d > 0) produce
        // valid colors; the silhouette mask alpha-blends them out.
        float t = clamp(depthPx / refractThickness, 0.0, 1.0);
        float sinThetaI = (1.0 - t) * (1.0 - t);
        float thetaI = asin(clamp(sinThetaI, 0.0, 1.0));
        float sinThetaT = sinThetaI / refractIOR;
        float thetaT = asin(clamp(sinThetaT, 0.0, 1.0));
        float edgeMag = tan(thetaI - thetaT);

        vec2 displacePx = -ndir * edgeMag * refractScale;
        vec2 displaceUV = displacePx / size;

        float edgeWeight = 1.0 - t;
        float chromaPx = chromaStrength * refractThickness * 0.35 * edgeWeight;
        vec2 chromaUV = -ndir * chromaPx / size;

        col.r = sampleBackdrop(uv + displaceUV + chromaUV).r;
        col.g = sampleBackdrop(uv + displaceUV).g;
        col.b = sampleBackdrop(uv + displaceUV - chromaUV).b;

        col = mix(col, tint.rgb, tint.a);

        // Corner specular — hairline stroke on the silhouette (self-gated
        // by its own stroke-thickness test in depthPx).
        col += cornerSpec(p, depthPx);
    }

    // Final AA mask at the silhouette. Feather ~2.5px centered slightly
    // inside the geometric edge so the outer rim softens into the
    // backdrop instead of showing stepped squircle pixels.
    float mask = 1.0 - smoothstep(-1.5, 1.0, d);
    fragColor = vec4(col, mask) * qt_Opacity;
}
