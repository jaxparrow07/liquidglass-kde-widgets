import QtQuick

// GitHub-style contribution heatmap, drawn on a Canvas so it scales cleanly
// without allocating one QML Item per day (a year is 365+ cells).
//
// Input is an array of { date, level, count } entries as produced by
// GitHubData. The grid is column-major: each column is one week, each row a
// day of the week (Sunday at the top). Cell positions are derived from the
// dates themselves rather than any fixed 53-week assumption, so a partial
// leading or trailing week renders correctly.
Canvas {
    id: graph

    property var cells: []
    property color foreground: "#ffffff"
    property var levels: ["#161b22", "#0e4429", "#006d32", "#26a641", "#39d353"]
    property string fontFamily: ""

    onCellsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onForegroundChanged: requestPaint()
    onLevelsChanged: requestPaint()

    // Date helpers. All dates are local midnights, so day math uses whole
    // milliseconds and rounds the difference to absorb DST shifts.
    function _startSunday(iso) {
        var d = new Date(iso + "T00:00:00")
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - d.getDay())
    }
    function _weekCol(start, d) {
        var days = Math.round((d.getTime() - start.getTime()) / 86400000)
        return Math.floor(days / 7)
    }
    function _font(px) {
        var family = fontFamily !== "" ? fontFamily : "sans-serif"
        return Math.round(px) + "px '" + family + "'"
    }
    function _faint(alpha) {
        return Qt.rgba(foreground.r, foreground.g, foreground.b, alpha)
    }
    function _roundedRect(ctx, x, y, w, h, r) {
        if (r <= 0) { ctx.rect(x, y, w, h); return }
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.quadraticCurveTo(x + w, y, x + w, y + r)
        ctx.lineTo(x + w, y + h - r)
        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
        ctx.lineTo(x + r, y + h)
        ctx.quadraticCurveTo(x, y + h, x, y + h - r)
        ctx.lineTo(x, y + r)
        ctx.quadraticCurveTo(x, y, x + r, y)
        ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        if (width <= 1 || height <= 1) return

        var list = graph.cells
        if (!list || list.length === 0) return

        var start = graph._startSunday(list[0].date)

        // Number of week columns covered by the data.
        var cols = 0
        for (var i = 0; i < list.length; i++) {
            var d = new Date(list[i].date + "T00:00:00")
            var c = graph._weekCol(start, d)
            if (c + 1 > cols) cols = c + 1
        }
        var rows = 7

        // Reserve a strip for month labels on top and weekday labels on the left.
        var topH = Math.round(height * 0.10)
        var leftW = Math.round(width * 0.055)
        var gridW = width - leftW
        var gridH = height - topH

        var gap = Math.max(1, Math.floor(Math.min(width, height) * 0.01))
        var cell = Math.floor(Math.min((gridW - gap * (cols - 1)) / cols,
                                       (gridH - gap * (rows - 1)) / rows))
        if (cell < 2) cell = 2
        var totalW = cell * cols + gap * (cols - 1)
        var totalH = cell * rows + gap * (rows - 1)
        var ox = leftW + Math.floor((gridW - totalW) / 2)
        var oy = topH + Math.floor((gridH - totalH) / 2)

        var labelPx = Math.max(9, Math.min(13, Math.round(cell * 0.85)))

        // Weekday labels (Mon / Wed / Fri, matching GitHub).
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var dayRows = [1, 3, 5]
        ctx.font = graph._font(labelPx)
        ctx.fillStyle = graph._faint(0.55)
        ctx.textBaseline = "middle"
        for (var di = 0; di < dayRows.length; di++) {
            var r = dayRows[di]
            ctx.fillText(dayNames[r], 0, oy + r * (cell + gap) + cell / 2)
        }

        // Month labels above the column that contains the first of each month.
        var first = new Date(list[0].date + "T00:00:00")
        var last = new Date(list[list.length - 1].date + "T00:00:00")
        var y0 = first.getFullYear()
        var m0 = first.getMonth()
        var totalMonths = (last.getFullYear() - y0) * 12 + (last.getMonth() - m0) + 1
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var lastLabelRight = -Infinity
        for (var mi = 0; mi < totalMonths; mi++) {
            var abs = m0 + mi
            var yr = y0 + Math.floor(abs / 12)
            var mm = abs % 12
            var firstOfMonth = new Date(yr, mm, 1)
            var col = graph._weekCol(start, firstOfMonth)
            if (col < 0 || col >= cols) continue
            var label = months[mm]
            var tw = ctx.measureText(label).width
            var lx = ox + col * (cell + gap)
            if (lx - lastLabelRight < tw + gap) continue
            ctx.fillText(label, lx, topH * 0.55)
            lastLabelRight = lx + tw
        }

        // Cells.
        var ramp = graph.levels || []
        for (var j = 0; j < list.length; j++) {
            var day = list[j]
            var dd = new Date(day.date + "T00:00:00")
            var col2 = graph._weekCol(start, dd)
            var row = dd.getDay()
            var color = ramp[day.level] !== undefined ? ramp[day.level] : ramp[4]
            var x = ox + col2 * (cell + gap)
            var yy = oy + row * (cell + gap)
            ctx.fillStyle = color
            ctx.beginPath()
            graph._roundedRect(ctx, x, yy, cell, cell, Math.max(1, Math.round(cell * 0.18)))
            ctx.fill()
        }
    }
}
