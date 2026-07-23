#version 440

// Text-shaped liquid-glass fragment shader.
//
// A fork of liquidglass.frag whose silhouette comes from a precomputed glyph
// signed distance field (glyph_sdf.frag) rather than the analytic squircle
// SDF. Everything downstream — Snell-on-a-dome edge refraction, chromatic
// dispersion, edge specular lip, and the premultiplied AA silhouette mask —
// is identical to liquidglass.frag; only the source of (d, normal) differs,
// so each glyph contour behaves as a real glass body edge.
//
// The squircle corner specular (cornerSpec) is intentionally dropped: glyphs
// have no four-corner concept. The edge lip (edgeSpec) follows every contour.
//
// qt_TexCoord0 is widget-local UV (0..1).
// uvOffset/uvScale map widget UV -> wallpaper UV (when blur is off).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  size;              // widget size in px
    float refractThickness;  // edge band width in px
    float refractIOR;
    float refractScale;
    float chromaStrength;    // 0..1 chromatic aberration
    float sdfRange;          // px span packed into sdfTex.b (matches glyph_sdf)
    float solidMode;         // 1 = opaque fill, skip refraction
    float fallbackMode;      // 1 = translucent glyph fill (no wallpaper)
    float fallbackOpacity;   // alpha for the fallback fill
    vec4  tint;
    vec2  uvOffset;
    vec2  uvScale;
    float specStrength;      // 0..1 intensity
};

layout(binding = 1) uniform sampler2D backdrop;
layout(binding = 2) uniform sampler2D sdfTex;   // rg=normal, b=signed dist, a=coverage
layout(binding = 3) uniform sampler2D maskTex;  // SHARP glyph coverage (a) — clips output

// Unpack the glyph SDF: returns vec3(d_px, nx, ny).
vec3 glyphSDFAndNormal(vec2 uv) {
    vec4 s = texture(sdfTex, uv);
    float d = (s.b - 0.5) * 2.0 * sdfRange;
    vec2  n = s.rg * 2.0 - vec2(1.0);
    float l = length(n);
    n = l > 1e-4 ? n / l : vec2(0.0, -1.0);
    return vec3(d, n);
}

vec3 sampleBackdrop(vec2 localUV) {
    vec2 wpUV = clamp(uvOffset + localUV * uvScale, vec2(0.0), vec2(1.0));
    return texture(backdrop, wpUV).rgb;
}

// Glass rim sheen along every glyph contour, driven by the contour normal.
//
// The band is a THIN, FIXED-px edge rim (not scaled to refractThickness): on
// small/thin glyphs a wide band swamps the whole stroke and shades it top-bright
// / bottom-dim, which reads as choppy. A 3px rim stays an edge rim on glyphs of
// any size. The directional key-light modulation is GENTLE (high floor) so the
// rim doesn't split into two tones on thin strokes.
vec3 edgeSpec(vec2 ndir, float depthPx) {
    if (specStrength <= 0.0) return vec3(0.0);

    // Thin rim right at the contour, fading inward over ~4 px regardless of
    // glyph size. clamp keeps the outer feather (depthPx < 0) at full.
    float rim = 1.0 - smoothstep(0.0, 4.0, max(depthPx, 0.0));
    rim = rim * rim;   // sharpen to a crisp glassy edge

    vec2 keyDir = normalize(vec2(-0.55, 0.83));   // top-left key light
    float align = dot(ndir, keyDir);              // -1..1
    // Gentle directional shading: 0.7 floor + 0.3 toward the light. Keeps the
    // whole rim lit so thin strokes don't read as half-bright/half-dim.
    float facing = 0.7 + 0.3 * (align * 0.5 + 0.5);

    // Global damping kept low so the rim is a soft sheen, not a hard white line.
    float I = rim * facing * specStrength * 0.22;
    return vec3(1.0, 0.985, 0.96) * I;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 dn = glyphSDFAndNormal(uv);
    float d = dn.x;          // signed px distance to contour (neg inside)
    vec2 ndir = dn.yz;       // unit outward normal
    float depthPx = -d;      // depth into the glyph from its contour

    // Sharp glyph coverage from the original (un-blurred) text raster. This is
    // the authoritative silhouette: it hard-clips ALL output to the true glyph
    // shape, so refraction can never spill past the letter edge, and it carries
    // the font rasteriser's own antialiasing for clean edges.
    float mask = texture(maskTex, uv).a;
    if (mask <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    if (solidMode > 0.5) {
        // Opaque fill (panels / no-wallpaper fallback): flat tinted glyph.
        vec3 col = tint.rgb + edgeSpec(ndir, depthPx);
        fragColor = vec4(col * mask, mask) * qt_Opacity;
        return;
    }

    if (fallbackMode > 0.5) {
        // Glass mode but no wallpaper to refract (plasmoidviewer / panels):
        // translucent tinted glyph so the widget is still visible.
        float a = mask * fallbackOpacity;
        vec3 col = tint.rgb + edgeSpec(ndir, depthPx);
        fragColor = vec4(col * a, a) * qt_Opacity;
        return;
    }

    vec3 col;
    bool canRefract = refractThickness > 0.0;

    vec3 tintColor = tint.rgb;
    float tintAlpha = tint.a;

    if (!canRefract || depthPx >= refractThickness || depthPx <= 0.0) {
        // Interior of a stroke OR the outer AA feather: flat glass
        // (pass-through + tint), no displacement. Refracting in the outer
        // feather (depthPx <= 0) would sample far-off wallpaper and smear a
        // colored halo around the glyph — so we explicitly exclude it.
        col = sampleBackdrop(uv);
        col = mix(col, tintColor, tintAlpha);
    } else {
        // --- Edge band: Snell on a dome (only inside, 0 < depthPx < thick) ---
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

        col = mix(col, tintColor, tintAlpha);
    }

    col += edgeSpec(ndir, depthPx);

    // Qt Quick blends ShaderEffect output as premultiplied alpha. `mask` is the
    // sharp glyph coverage sampled above — output is hard-contained in the glyph.
    fragColor = vec4(col * mask, mask) * qt_Opacity;
}
