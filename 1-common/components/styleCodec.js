.pragma library

// Short clipboard keys <-> plasmoid config keys. Must match the keys written by
// GlassAppearancePage._serialize() (and the variants' serializeExtras).
const KEYS = {
    s: "styleMode",
    as: "autoStyle",
    a: "appearance",
    cr: "cornerRadius",
    rn: "roundnessX10",
    ta: "tintAlphaPct",
    rt: "refractThickness",
    ri: "refractIORx100",
    rs: "refractScale",
    ca: "chromaStrengthPct",
    ss: "specStrengthPct",
    ba: "blurAlgorithm",
    br: "blurRadiusPx",
    rr: "realtimeRefraction",
    ob: "opaqueBackground",
    gf: "glyphFont",
    tt: "textTintPct",
    tc: "textColor"
}

// Applies a copied-style JSON string to `config`. Keys the widget doesn't have
// are skipped. Returns true if the text was a style.
function apply(config, text) {
    let o
    try { o = JSON.parse(text) } catch (e) { return false }
    if (!o || typeof o !== "object" || o.s === undefined) return false
    for (const k in KEYS) {
        if (o[k] === undefined) continue
        const name = KEYS[k]
        if (config[name] === undefined) continue
        config[name] = o[k]
    }
    return true
}
