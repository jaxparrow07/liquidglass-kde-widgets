import QtQuick

// 60 radial tick marks at true clock angles. Each tick is a pill-shaped
// stroke running from an inner squircle frame to an outer squircle frame.
// Corner ticks naturally become longer than straight-edge ticks because
// the ray distance between inset squircles is larger through the corners.
//
// Clock convention: 0° = 12 o'clock, clockwise positive.
Item {
    id: root

    // Outer frame = widget silhouette shrunk by outerInset (fraction of min-side).
    property real outerInset: 0.05
    // Inner frame = widget silhouette shrunk by outerInset + tickLength.
    property real tickLength: 0.05
    // Pull corner ticks slightly outward so their gap to the edge feels
    // closer to the gap they leave on the inside.
    property real cornerOuterExtension: 0.012

    // Squircle parameters, matching the glass shape.
    property real cornerRadius: 100
    property real roundness: 5.5

    property real baseOpacity: 0.18
    property real tickWidthPx: 2.2
    property color tickColor: "#ffffff"

    // Second-hand angle in degrees (0 = 12 o'clock, CW positive).
    property real secondHandAngle: 0

    // How far the trailing fade extends behind the head.
    readonly property real trailingArc: 270.0

    readonly property real _minSide: Math.min(width, height)

    // Precomputed endpoint arrays: {x, y} for each of 60 ticks.
    property var _ticksOuter: []
    property var _ticksInner: []

    // --- Squircle SDF (same math as the shader) --------------------------
    //
    // Superellipse-cornered rounded rect, centered at origin, half-extents
    // (hw, hh), corner radius r, exponent n. Signed distance: negative
    // inside, positive outside. This is the level-set value; for the
    // purposes of "is this point inside?" and "find boundary along a ray"
    // the level-set sign is what matters, not Euclidean distance.
    function _squircleLevel(x, y, hw, hh, r, n) {
        const ax = Math.abs(x);
        const ay = Math.abs(y);
        const qx = ax - hw + r;
        const qy = ay - hh + r;
        if (qx <= 0 && qy <= 0) {
            // Interior relative to the inner straight-edge box; distance
            // is max(qx,qy) which is negative.
            return Math.max(qx, qy) - r;
        }
        const mx = Math.max(qx, 0);
        const my = Math.max(qy, 0);
        // p-norm for corner wedge; straight edge degenerates to |mx|/|my|.
        const arc = Math.pow(Math.pow(mx, n) + Math.pow(my, n), 1 / n);
        return Math.min(Math.max(qx, qy), 0) + arc - r;
    }

    // Find t ≥ 0 where the ray from origin (cx, cy) at direction
    // (dx, dy) crosses the squircle boundary. Bisection from a safe
    // bracket. Pure-JS, called 60× per geometry change — cost trivial.
    function _squircleRayHit(cx, cy, dx, dy, hw, hh, r, n) {
        // Start by bounding t with the axis-aligned bounding rectangle.
        const tX = Math.abs(dx) > 1e-9 ? hw / Math.abs(dx) : Infinity;
        const tY = Math.abs(dy) > 1e-9 ? hh / Math.abs(dy) : Infinity;
        let tHi = Math.min(tX, tY);
        // For n >= 2 the squircle lies inside its bounding rect along
        // the 45° diagonal (at n=2 the inscribed circle is smaller than
        // the square's diagonal), so tHi is >= the true hit. For n→∞
        // the squircle approaches the full rect, so tHi approaches the
        // true hit. Either way tHi is a valid upper bracket.
        //
        // Lower bracket: any t where we're still inside. 0 works if the
        // origin is inside; otherwise the ray doesn't intersect a
        // centered squircle enclosing the origin, which can't happen
        // here (cx=cy=0 is always inside).
        let tLo = 0;
        // 20 iterations of bisection → ~1e-6 * tHi precision. Plenty.
        for (let i = 0; i < 24; i++) {
            const tm = 0.5 * (tLo + tHi);
            const lvl = _squircleLevel(tm * dx, tm * dy, hw, hh, r, n);
            if (lvl < 0)
                tLo = tm;
            else
                tHi = tm;
        }
        const t = 0.5 * (tLo + tHi);
        return {
            x: cx + t * dx,
            y: cy + t * dy
        };
    }

    function _rebuild() {
        const cx = width / 2;
        const cy = height / 2;

        const outerInsetPx = outerInset * _minSide;
        const innerPad = (outerInset + tickLength) * _minSide;
        const cornerExtensionPx = cornerOuterExtension * _minSide;

        const outer = new Array(60);
        const inner = new Array(60);
        for (let i = 0; i < 60; i++) {
            const rad = i * 6 * Math.PI / 180;
            const dx = Math.sin(rad);
            const dy = -Math.cos(rad);

            // 0 on flat edges, 1 on the 45° corner diagonals.
            const cornerBlend = 1 - Math.abs(Math.abs(dx) - Math.abs(dy));
            const tickOuterInsetPx = Math.max(0, outerInsetPx - cornerExtensionPx * cornerBlend);

            const outerHw = Math.max(1, width / 2 - tickOuterInsetPx);
            const outerHh = Math.max(1, height / 2 - tickOuterInsetPx);
            const outerR = Math.max(0, cornerRadius - tickOuterInsetPx);

            const innerHw = Math.max(1, width / 2 - innerPad);
            const innerHh = Math.max(1, height / 2 - innerPad);
            const innerR = Math.max(0, cornerRadius - innerPad);

            outer[i] = _squircleRayHit(cx, cy, dx, dy, outerHw, outerHh, outerR, roundness);
            inner[i] = _squircleRayHit(cx, cy, dx, dy, innerHw, innerHh, innerR, roundness);
        }
        _ticksOuter = outer;
        _ticksInner = inner;
        canvas.requestPaint();
    }

    onWidthChanged: _rebuild()
    onHeightChanged: _rebuild()
    onOuterInsetChanged: _rebuild()
    onTickLengthChanged: _rebuild()
    onCornerOuterExtensionChanged: _rebuild()
    onCornerRadiusChanged: _rebuild()
    onRoundnessChanged: _rebuild()
    Component.onCompleted: _rebuild()

    onSecondHandAngleChanged: canvas.requestPaint()
    onBaseOpacityChanged: canvas.requestPaint()
    onTickWidthPxChanged: canvas.requestPaint()
    onTickColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Immediate

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root._ticksOuter || root._ticksOuter.length !== 60)
                return;
            const base = root.baseOpacity;
            // Comet trail length: 270° behind the prev tick.
            const trailDeg = 270.0;

            // Discrete-step head with sub-second crossfade. The trail
            // is anchored to the PREVIOUS tick (not the continuous
            // angle), so it doesn't out-bright the head crossfade. The
            // animation is still 60fps because `sHead` (the crossfade
            // fraction) is recomputed every paint, which happens every
            // 16ms via secondHandAngle updates.
            const pos = root.secondHandAngle / 6.0;
            const curIdx = Math.floor(pos) % 60;
            const prevIdx = (curIdx - 1 + 60) % 60;
            // Sub-second crossfade fraction for the head, eased.
            let fadeT = pos - Math.floor(pos);
            if (fadeT < 0)
                fadeT = 0;
            else if (fadeT > 1)
                fadeT = 1;
            const sHead = fadeT * fadeT * (3 - 2 * fadeT);

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.lineWidth = root.tickWidthPx;
            ctx.strokeStyle = Qt.rgba(root.tickColor.r, root.tickColor.g, root.tickColor.b, 1);

            for (let i = 0; i < 60; i++) {
                let s = 0;   // base envelope above baseOpacity, in [0, 1]

                if (i === curIdx) {
                    // New head: crossfade in from base to full bright.
                    s = sHead;
                } else {
                    // Trail anchored at the previous tick. Degrees this
                    // tick is BEHIND prevIdx along the dial (clockwise
                    // semantics: positive = older).
                    const angle = i * 6;
                    const prevAngle = prevIdx * 6;
                    const off = (prevAngle - angle + 360) % 360;
                    if (off >= 0 && off <= trailDeg) {
                        // u = 1 at prevIdx (head of trail), 0 at the
                        // far end where it has fully faded to base.
                        const u = 1 - off / trailDeg;
                        s = Math.pow(u, 0.6);
                    }
                }

                const op = base + (1 - base) * s;
                const o = root._ticksOuter[i];
                const ii = root._ticksInner[i];
                ctx.globalAlpha = op;
                ctx.beginPath();
                ctx.moveTo(ii.x, ii.y);
                ctx.lineTo(o.x, o.y);
                ctx.stroke();
            }
            ctx.globalAlpha = 1;
        }
    }
}
