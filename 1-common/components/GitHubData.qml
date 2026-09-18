import QtQuick

// GitHub data backend shared by the GitHub contribution widgets.
//
// Contribution cells are scraped from the public profile-page fragment at
// https://github.com/users/<username>/contributions (no account, OAuth or
// token required). Each <td class="ContributionCalendar-day"> carries a
// data-date / data-level pair and is immediately followed by its <tool-tip>
// which holds the exact per-day count, so the two are parsed together.
//
// When fetchProfile is enabled the account info (login + avatar) is scraped
// from the public profile page https://github.com/<username>. This stays on
// github.com rather than the REST API, which is rate-limited to 60 requests
// per hour per IP when unauthenticated and would fail with a 403.
QtObject {
    id: gh

    property string username: ""
    property bool fetchProfile: false

    property bool isLoading: true
    property string errorMessage: ""

    // Contribution data (array of { date, level, count }).
    property var cells: []
    property int totalCount: 0
    property string yearLabel: ""

    // Account data.
    property string login: ""
    property string displayName: ""
    property string avatarUrl: ""

    property var _refreshTimer: Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: gh._fetch()
    }

    property int _failCount: 0
    readonly property var _backoffSchedule: [5000, 10000, 20000, 40000, 80000, 160000, 300000]

    property var _retryTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: gh._fetch()
    }

    function _scheduleRetry() {
        _failCount = Math.min(_failCount + 1, _backoffSchedule.length - 1)
        _retryTimer.interval = _backoffSchedule[_failCount]
        _retryTimer.restart()
    }

    function _clearRetry() {
        _failCount = 0
        _retryTimer.stop()
    }

    function forceRefresh() {
        _retryTimer.stop()
        _failCount = 0
        _fetch()
    }

    onUsernameChanged: _refreshFromConfig()

    Component.onCompleted: _refreshFromConfig()

    function _refreshFromConfig() {
        _retryTimer.stop()
        _failCount = 0
        if (username.trim() === "") {
            isLoading = false
            errorMessage = ""
            cells = []
            totalCount = 0
            yearLabel = ""
            login = ""
            displayName = ""
            avatarUrl = ""
            return
        }
        _fetch()
    }

    function _fetch() {
        var u = username.trim()
        if (u === "") return
        isLoading = true
        errorMessage = ""
        _fetchContributions(u)
        if (fetchProfile) _fetchProfile(u)
    }

    function _fetchContributions(u) {
        var xhr = new XMLHttpRequest()
        var url = "https://github.com/users/" + encodeURIComponent(u) + "/contributions"
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var parsed = gh._parseContributions(xhr.responseText)
                    cells = parsed.cells
                    totalCount = parsed.total
                    yearLabel = parsed.yearLabel
                    isLoading = false
                    errorMessage = ""
                    _clearRetry()
                } catch (e) {
                    errorMessage = i18n("Could not parse the contribution data")
                    isLoading = false
                    _scheduleRetry()
                }
            } else if (xhr.status === 404) {
                errorMessage = i18n("GitHub user not found")
                isLoading = false
                _clearRetry()
            } else {
                errorMessage = i18n("Failed to fetch contributions")
                isLoading = false
                _scheduleRetry()
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _fetchProfile(u) {
        var xhr = new XMLHttpRequest()
        var url = "https://github.com/" + encodeURIComponent(u)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var html = xhr.responseText
                    // The profile header carries the avatar and the canonical
                    // username in a single <img class="avatar-user" ...> tag.
                    var m = /class="[^"]*avatar-user[^"]*"[^>]*src="([^"]+)"[^>]*alt="@([^"]+)"/.exec(html)
                    if (m) {
                        avatarUrl = m[1].replace(/&amp;/g, "&").replace(/s=\d+/, "s=256")
                        login = m[2]
                    } else {
                        login = u
                    }
                } catch (e) {}
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _parseContributions(html) {
        var cells = []
        var re = /data-date="(\d{4}-\d{2}-\d{2})"[^>]*data-level="([0-4])"[^>]*>\s*<\/td>\s*<tool-tip[^>]*>([^<]*)<\/tool-tip>/g
        var m
        while ((m = re.exec(html)) !== null) {
            var count = 0
            if (m[3].indexOf("No contributions") !== 0) {
                var nm = /(\d+)/.exec(m[3])
                if (nm) count = parseInt(nm[1], 10)
            }
            cells.push({ date: m[1], level: parseInt(m[2], 10), count: count })
        }

        var total = 0
        for (var i = 0; i < cells.length; i++) total += cells[i].count

        var yearLabel = ""
        if (cells.length > 0) {
            yearLabel = _formatDate(cells[0].date) + " - " + _formatDate(cells[cells.length - 1].date)
        }

        return { cells: cells, total: total, yearLabel: yearLabel }
    }

    function _formatDate(iso) {
        var d = new Date(iso + "T00:00:00")
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
    }
}
