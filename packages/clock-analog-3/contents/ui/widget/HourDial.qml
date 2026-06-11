import QtQuick

// 60 radial tick marks following the squircle perimeter. All ticks are
// static (no second-hand animation). The 12 hour positions (every 5th tick)
// are drawn darker and longer — their inner tips all land on a perfect
// circle of radius hourCircleRadiusFrac × (min-side / 2).
Item {
    id: root

    // Outer frame = widget silhouette shrunk by outerInset (fraction of min-side).
    property real outerInset: 0.05
    // Inner frame for normal (non-hour) ticks.
    property real tickLength: 0.026
    // Pull corner ticks slightly outward so their gap to the edge feels consistent.
    property real cornerOuterExtension: 0.012

    // Squircle parameters matching the glass shape.
    property real cornerRadius: 100
    property real roundness: 5.5

    property real baseOpacity: 0.18
    // Hour ticks are only slightly lighter than the rest (~25% brighter),
    // not a hard white/black. Resolved by the caller as baseOpacity * ~1.25.
    property real hourOpacity: 0.225
    property real tickWidthPx: 2.2
    // Hour ticks are ~32% thicker than the normal perimeter ticks.
    property real hourWidthPx: tickWidthPx * 1.3225
    property color tickColor: "#ffffff"

    // Inner tips of the 12 hour ticks land on a circle of this radius
    // (as a fraction of min-side / 2). 10% shorter than the original spec:
    // a larger radius means a shorter inward line.
    property real hourCircleRadiusFrac: 0.699

    readonly property real _minSide: Math.min(width, height)
    readonly property real _r: _minSide / 2

    property var _ticksOuter: []
    property var _ticksInner: []  // normal ticks
    property var _hourInner: []   // hour ticks (circle-based inner endpoints)

    // --- Squircle SDF (same math as the shader) ---
    function _squircleLevel(x, y, hw, hh, r, n) {
        const ax = Math.abs(x);
        const ay = Math.abs(y);
        const qx = ax - hw + r;
        const qy = ay - hh + r;
        if (qx <= 0 && qy <= 0) {
            return Math.max(qx, qy) - r;
        }
        const mx = Math.max(qx, 0);
        const my = Math.max(qy, 0);
        const arc = Math.pow(Math.pow(mx, n) + Math.pow(my, n), 1 / n);
        return Math.min(Math.max(qx, qy), 0) + arc - r;
    }

    function _squircleRayHit(cx, cy, dx, dy, hw, hh, r, n) {
        const tX = Math.abs(dx) > 1e-9 ? hw / Math.abs(dx) : Infinity;
        const tY = Math.abs(dy) > 1e-9 ? hh / Math.abs(dy) : Infinity;
        let tHi = Math.min(tX, tY);
        let tLo = 0;
        for (let i = 0; i < 24; i++) {
            const tm = 0.5 * (tLo + tHi);
            const lvl = _squircleLevel(tm * dx, tm * dy, hw, hh, r, n);
            if (lvl < 0)
                tLo = tm;
            else
                tHi = tm;
        }
        const t = 0.5 * (tLo + tHi);
        return { x: cx + t * dx, y: cy + t * dy };
    }

    function _rebuild() {
        const cx = width / 2;
        const cy = height / 2;

        const outerInsetPx = outerInset * _minSide;
        const innerPad = (outerInset + tickLength) * _minSide;
        const cornerExtensionPx = cornerOuterExtension * _minSide;
        const circleR = hourCircleRadiusFrac * _r;

        const outer = new Array(60);
        const inner = new Array(60);
        const hourIn = new Array(60);

        for (let i = 0; i < 60; i++) {
            const rad = i * 6 * Math.PI / 180;
            const dx = Math.sin(rad);
            const dy = -Math.cos(rad);

            const cornerBlend = 1 - Math.abs(Math.abs(dx) - Math.abs(dy));
            const tickOuterInsetPx = Math.max(0, outerInsetPx - cornerExtensionPx * cornerBlend);

            const outerHw = Math.max(1, width / 2 - tickOuterInsetPx);
            const outerHh = Math.max(1, height / 2 - tickOuterInsetPx);
            const outerR  = Math.max(0, cornerRadius - tickOuterInsetPx);

            const innerHw = Math.max(1, width / 2 - innerPad);
            const innerHh = Math.max(1, height / 2 - innerPad);
            const innerR  = Math.max(0, cornerRadius - innerPad);

            const oPt = _squircleRayHit(cx, cy, dx, dy, outerHw, outerHh, outerR, roundness);
            outer[i]  = oPt;
            inner[i]  = _squircleRayHit(cx, cy, dx, dy, innerHw, innerHh, innerR, roundness);
            // Hour tick inner endpoint: on the fixed circle, same radial direction,
            // then pulled 10% of the line length back toward the outer point so the
            // hour lines are 10% shorter.
            const circX = cx + dx * circleR;
            const circY = cy + dy * circleR;
            hourIn[i] = { x: circX + (oPt.x - circX) * 0.10,
                          y: circY + (oPt.y - circY) * 0.10 };
        }
        _ticksOuter = outer;
        _ticksInner = inner;
        _hourInner  = hourIn;
        canvas.requestPaint();
    }

    onWidthChanged:               _rebuild()
    onHeightChanged:              _rebuild()
    onOuterInsetChanged:          _rebuild()
    onTickLengthChanged:          _rebuild()
    onCornerOuterExtensionChanged: _rebuild()
    onCornerRadiusChanged:        _rebuild()
    onRoundnessChanged:           _rebuild()
    onHourCircleRadiusFracChanged: _rebuild()
    Component.onCompleted:        _rebuild()

    onBaseOpacityChanged: canvas.requestPaint()
    onHourOpacityChanged: canvas.requestPaint()
    onTickWidthPxChanged: canvas.requestPaint()
    onHourWidthPxChanged: canvas.requestPaint()
    onTickColorChanged:   canvas.requestPaint()

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

            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            for (let i = 0; i < 60; i++) {
                const isHour = (i % 5 === 0);
                const op = isHour ? root.hourOpacity : root.baseOpacity;
                ctx.globalAlpha = op;
                ctx.lineWidth = isHour ? root.hourWidthPx : root.tickWidthPx;
                ctx.strokeStyle = Qt.rgba(root.tickColor.r, root.tickColor.g, root.tickColor.b, 1);

                const o  = root._ticksOuter[i];
                const ii = isHour ? root._hourInner[i] : root._ticksInner[i];

                ctx.beginPath();
                ctx.moveTo(ii.x, ii.y);
                ctx.lineTo(o.x, o.y);
                ctx.stroke();
            }
            ctx.globalAlpha = 1;
        }
    }
}
