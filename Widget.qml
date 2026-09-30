import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Odropsy: every personal assistant behind one bar icon. bin/drops-watch
// streams the Grok Bot roster plus the web assistants (Muse, Dots); whoever is
// waiting on you shows up beside the icon, and a click on a row drops that chat
// down from the bar (bin/drop-toggle). Built on omabot by Neil Patel
// (Apache-2.0, see LICENSE-omabot). Keys: j/k move · Enter open · h redact ·
// r cycle the bar text · g group · Esc close.

Panel {
  id: root
  moduleName: "telep.drops"
  ipcTarget: "telep.drops"
  manageIpc: false

  // ---------------------------------------------------------------- settings
  // The logo is always in the bar. This is only what sits beside it:
  // the bots that want you, drawn as themselves; how many there are; or nothing.
  property string barMetric: {
    var v = String(setting("barMetric", "avatars"))
    return barMetrics.indexOf(v) >= 0 ? v : (v === "count" ? "count" : "avatars")
  }
  readonly property var barMetrics: ["avatars", "count", "none"]
  // persist=false changes it for this session only. Writing the bar entry
  // reloads the widget, which would throw away anything held in memory, so a
  // scripted walk through the states asks for it.
  function cycleBarMetric(persist) {
    barMetric = barMetrics[(barMetrics.indexOf(barMetric) + 1) % barMetrics.length]
    if (persist !== false)
      Quickshell.execDetached(["omarchy", "bar", "set", "telep.drops", "barMetric", barMetric])
  }

  // attention: whoever wants you first (oldest wait first, so nobody is
  // buried), a rule, then everyone else by recency. channels: the sidebar
  // sections you set up in Grok Bot. flat: purely by recency.
  property string ordering: String(setting("ordering", "attention"))
  readonly property var orderings: ["attention", "channels", "flat"]
  function cycleOrdering() {
    ordering = orderings[(orderings.indexOf(ordering) + 1) % orderings.length]
    Quickshell.execDetached(["omarchy", "bar", "set", "telep.drops", "ordering", ordering])
    cursor = 0
  }
  property bool groupBySection: String(setting("groupBySection", "true")) !== "false"
  function toggleGrouping() {
    groupBySection = !groupBySection
    Quickshell.execDetached(["omarchy", "bar", "set", "telep.drops", "groupBySection", groupBySection ? "true" : "false"])
  }

  readonly property int maxBarAvatars: Math.max(1, Math.min(6, Number(setting("maxBarAvatars", 3))))
  readonly property string watcher: Qt.resolvedUrl("bin/drops-watch").toString().replace(/^file:\/\//, "")

  function setting(name, fallback) {
    var s = root.settings || ({})
    return s[name] !== undefined && s[name] !== null ? s[name] : fallback
  }

  // ---------------------------------------------------------------- theme
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
  readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.20)
  readonly property color divider: Qt.rgba(fg.r, fg.g, fg.b, 0.34)
  readonly property color hilite: Qt.rgba(fg.r, fg.g, fg.b, 0.09)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color eyeInk: Color.background

  // ---------------------------------------------------------------- state
  property var liveSnap: null
  readonly property var snap: liveSnap

  // Which assistants to list, e.g. "dots,grok" if you have no Muse.
  readonly property var services: String(setting("services", "muse,dots,grok")).split(",")
    .map(function(x) { return x.trim() })
  property bool scrub: false
  property int cursor: 0
  property double nowMs: Date.now()

  readonly property var counts: snap && snap.counts ? snap.counts : ({})
  readonly property var bots: (snap && snap.bots ? snap.bots : [])
    .filter(function(b) { return root.services.indexOf(b.service) >= 0 })
  readonly property var sections: snap && snap.sections ? snap.sections : []
  readonly property var app: snap && snap.app ? snap.app : ({})
  readonly property bool alarming: (counts.awaiting || 0) > 0
  readonly property bool attention: alarming || (counts.unread || 0) > 0

  // Bots that want you, most recently active first: the bar shows these.
  readonly property var wanting: {
    var out = []
    for (var i = 0; i < bots.length; i++) {
      var b = bots[i]
      if (b.awaiting || b.working || b.unread > 0) out.push(b)
    }
    var rank = function(x) { return x.awaiting ? 0 : (x.working ? 1 : 2) }
    out.sort(function(a, b) {
      if (rank(a) !== rank(b)) return rank(a) - rank(b)
      return (b.last_activity_ts || 0) - (a.last_activity_ts || 0)
    })
    return out
  }

  // Expression carries state. Muted is not it: most bots ship with
  // notifications off, and a roster of sleeping avatars says nothing. Gone
  // quiet for a week does say something, so that is what dozes.
  readonly property double staleAfterS: 7 * 24 * 3600
  function faceFor(b) {
    if (b.awaiting) return "attentive"
    if (b.unread > 1) return "excited"
    if (b.unread > 0) return "curious"
    if (b.last_activity_ts && (nowMs / 1000 - b.last_activity_ts) > staleAfterS) return "drowsy"
    return "neutral"
  }
  function avatarFor(b) {
    var own = b.service !== "grok" ? String(setting(b.service + "Avatar", "")) : ""
    if (own !== "") return "file://" + own.replace(/^~/, Quickshell.env("HOME"))
    return b.avatar ? "file://" + b.avatar : ""
  }
  function colorFor(b) { return b.hex ? b.hex : (b.color === "black" ? fg : dim) }

  // Rows the cursor can land on, rebuilt whenever the view changes.
  readonly property var rows: {
    var out = []
    if (!snap) return out
    if (ordering === "attention") {
      var wants = [], rest = []
      for (var b = 0; b < bots.length; b++) {
        var bot = bots[b]
        ;(bot.awaiting || bot.unread > 0 ? wants : rest).push(bot)
      }
      // Waiting longest first: the one that has been ignored most deserves the top.
      wants.sort(function(x, y) { return (x.last_activity_ts || 0) - (y.last_activity_ts || 0) })
      rest.sort(function(x, y) { return (y.last_activity_ts || 0) - (x.last_activity_ts || 0) })
      for (var w = 0; w < wants.length; w++) out.push({ kind: "bot", bot: wants[w] })
      if (wants.length > 0 && rest.length > 0) out.push({ kind: "rule" })
      for (var r2 = 0; r2 < rest.length; r2++) out.push({ kind: "bot", bot: rest[r2] })
      return out
    }
    if (ordering === "channels" && sections.length > 0) {
      var byId = ({})
      for (var i = 0; i < bots.length; i++) byId[bots[i].id] = bots[i]
      for (var s = 0; s < sections.length; s++) {
        var ids = sections[s].bot_ids || []
        if (ids.length === 0) continue
        out.push({ kind: "section", name: sections[s].name, count: ids.length })
        for (var k = 0; k < ids.length; k++) if (byId[ids[k]]) out.push({ kind: "bot", bot: byId[ids[k]] })
      }
    } else {
      var sorted = bots.slice().sort(function(a, b) {
        return (b.last_activity_ts || 0) - (a.last_activity_ts || 0)
      })
      for (var j = 0; j < sorted.length; j++) out.push({ kind: "bot", bot: sorted[j] })
    }
    return out
  }
  readonly property var botRows: {
    var out = []
    for (var i = 0; i < rows.length; i++) if (rows[i].kind === "bot") out.push(i)
    return out
  }

  // ---------------------------------------------------------------- watcher
  Process {
    id: watcherProc
    command: [root.watcher, "--interval", "2"]
    running: true
    stdout: SplitParser { onRead: function(data) { root.parseState(data) } }
    stderr: SplitParser {
      onRead: function(data) { if (String(data).trim() !== "") console.warn("drops", String(data).trim()) }
    }
    onExited: function(code) { console.warn("drops", "watcher exited", code); restartTimer.start() }
  }
  Timer { id: restartTimer; interval: 5000; onTriggered: watcherProc.running = true }

  function parseState(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object") { root.liveSnap = parsed; root.nowMs = Date.now() }
    } catch (e) {
      console.warn("drops", "bad state line", e)
    }
  }

  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: root.nowMs = Date.now() }

  onOpenedChanged: if (opened) {
    nowMs = Date.now()
    cursor = 0
    panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    requestGreeting(false)
  }


  // Rows greet themselves when this fires: each avatar owns its own timing,
  // so there is no central loop to fall out of step with the list.
  signal greetRequested(bool everyone)

  // The bar's own avatars look up when the pointer arrives, before the panel
  // is even open. Same shape as the panel's greeting: each one hears the
  // signal and owns its own timing.
  signal barGreeted()
  // Shifts which flourish each position gets, so the same three bots do not
  // do the same three things every time you pass the bar.
  property int barGreetSeed: 0

  Timer {
    id: greetOnOpen
    interval: 260
    onTriggered: root.greetRequested(greetEveryone)
    property bool greetEveryone: false
  }
  function requestGreeting(everyone) {
    dealFlourishes()
    greetOnOpen.greetEveryone = !!everyone
    greetOnOpen.restart()
  }

  // Greetings deal from a shuffled deck rather than rolling independently, so
  // three bots never all hop at once. Past a full deck it reshuffles, and it
  // will not repeat the card that was just played across that seam.
  property var flourishDeck: []
  property int flourishCount: 6
  property int lastFlourish: -1
  function dealFlourishes() {
    var deck = []
    for (var i = 0; i < flourishCount; i++) deck.push(i)
    for (var j = deck.length - 1; j > 0; j--) {
      var k = Math.floor(Math.random() * (j + 1))
      var t = deck[j]; deck[j] = deck[k]; deck[k] = t
    }
    if (deck.length > 1 && deck[deck.length - 1] === lastFlourish) {
      var swap = deck[0]; deck[0] = deck[deck.length - 1]; deck[deck.length - 1] = swap
    }
    flourishDeck = deck
  }
  function nextFlourish() {
    if (!flourishDeck || flourishDeck.length === 0) dealFlourishes()
    var deck = flourishDeck
    var pick = deck.pop()
    flourishDeck = deck
    lastFlourish = pick
    return pick
  }

  // Drop an assistant's chat down in place of the panel: the panel card is
  // sized like the chat, bin/drop-toggle puts the window at exactly the card's
  // rectangle, then the panel fades off it. Grok Bot has no deep link to a
  // single bot, so any Grok row drops the app and you pick in there.
  readonly property string toggleBin: Qt.resolvedUrl("bin/drop-toggle").toString().replace(/^file:\/\//, "")
  readonly property var screen: QsWindow.window ? QsWindow.window.screen : null
  readonly property int dropHeight: Math.round((screen ? screen.height : 1200) * Number(setting("heightPercent", 60)) / 100)
  property string dropped: ""        // service whose chat is down
  property string droppedAddr: ""
  property var dropRect: Qt.rect(0, 0, 0, 0)
  property string opening: ""        // name shown while an app launches

  function drop(verb, svc) {
    Quickshell.execDetached([toggleBin, verb].concat(svc ? [svc, String(setting(svc + "Url", ""))] : []))
  }
  function openBot(b) {
    if (!b || showProc.running) return
    if (!opened) open()
    opening = b.service === "grok" ? "Grok Bot" : b.name
    dropRect = Qt.rect(panel.cardOrigin.x, panel.cardOrigin.y, panel.contentWidth, panel.contentHeight)
    showProc.svc = b.service
    showProc.command = [toggleBin, "show", b.service, screen.name, String(Math.round(dropRect.x)),
                        String(Math.round(dropRect.y)), String(dropRect.width), String(dropRect.height),
                        String(setting(b.service + "Url", ""))]
    showProc.running = true
  }
  function openCursor() {
    var r = rows[cursor]
    if (r && r.kind === "bot") openBot(r.bot)
  }
  // Click off, "‹ all", or the icon: the chat goes back into hiding.
  function dismiss(backToList) {
    if (dropped === "") return
    dropped = ""
    if (!backToList) return drop("hide")
    open()
    tuckTimer.restart()   // once the panel has faded in over the chat
  }
  function popOut(svc) { dropped = ""; drop("popout", svc) }
  function closeChat(svc) { if (svc === dropped || svc === "all") dropped = ""; drop("close", svc) }

  Timer { id: tuckTimer; interval: 160; onTriggered: root.drop("hide") }

  Process {
    id: showProc
    property string svc: ""
    property string addr: ""
    onStarted: addr = ""
    stdout: SplitParser { onRead: function(data) { showProc.addr = String(data).trim() } }
    onExited: function(code) {
      root.opening = ""
      if (code === 0 && addr !== "") { root.droppedAddr = addr; root.dropped = svc }
      root.close()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.dropped === "") return
      if (event.name === "closewindow" && "0x" + event.data === root.droppedAddr) root.dropped = ""
      else if (event.name === "workspace") root.dismiss(false)
    }
  }

  // While a chat is down: a transparent sheet over the rest of the screen that
  // closes it when clicked, with a hole where the chat is (the bar strip stays
  // uncovered so the icon still works), and a tab strip under the chat.
  PanelWindow {
    id: catcher
    visible: root.bar !== null && root.dropped !== "" && root.screen !== null
    screen: root.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "telep-drops-catcher"
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
      y: root.dropRect.y
      width: catcher.width
      height: catcher.height - root.dropRect.y
      Region { item: hole; intersection: Intersection.Subtract }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: root.dismiss(false)
    }
    Item { id: hole; x: root.dropRect.x; y: root.dropRect.y; width: root.dropRect.width; height: root.dropRect.height }

    Row {
      x: hole.x + hole.width - width
      y: hole.y + hole.height + Style.space(4)
      spacing: Style.space(4)
      Repeater {
        model: [["‹ all", function() { root.dismiss(true) }],
                ["\u{f03cb} pop out", function() { root.popOut(root.dropped) }],
                ["✕ close", function() { root.closeChat(root.dropped) }]]
        Rectangle {
          required property var modelData
          width: tabText.implicitWidth + Style.space(16)
          height: tabText.implicitHeight + Style.space(8)
          radius: Style.space(6)
          color: root.bar ? root.bar.background : Color.background
          border.width: 1
          border.color: Qt.darker(tabText.color, 2)
          Text {
            id: tabText
            anchors.centerIn: parent
            text: modelData[0]
            color: root.bar ? root.bar.barForeground : Color.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData[1]() }
        }
      }
    }
  }

  IpcHandler {
    // Omarchy instantiates a bar widget more than once (a hidden copy is used
    // for measurement), and both copies would register for the same target -
    // the loser silently drops every call. Only the copy actually mounted in a
    // bar takes the name, so `omarchy-shell telep.drops …` reaches the one
    // on screen.
    enabled: root.bar !== null
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(service: string): void { root.openBot(root.bots.filter(function(b) { return b.service === service })[0]) }
    function hide(): void { root.dismiss(false) }
    function scrub(): string { root.scrub = !root.scrub; return root.scrub ? "scrubbed" : "clear" }
    function group(): string { root.cycleOrdering(); return root.ordering }
    function order(mode: string): string { root.ordering = mode; return root.ordering }
    // Play the greeting on demand: every bot, whether or not it has news.
    // Opens the panel first, because a panel loses focus - and closes - the
    // moment you type the command in a terminal.
    function greet(): string {
      if (!root.opened) root.open()
      root.requestGreeting(true)
      root.barGreetSeed += 1
      root.barGreeted()
      return "greeting"
    }
    function geometry(): string {
      return JSON.stringify({ x: panel.cardOrigin.x, y: panel.cardOrigin.y, w: panel.contentWidth, h: panel.contentHeight })
    }
    function metric(): string { root.cycleBarMetric(false); return root.barMetric }
    // Aim the eyes at a point in the panel, in its own coordinates. The eyes
    // follow a real pointer; this is how a recording without one drives them.
    function look(x: int, y: int): string {
      keyCatcher.pointerAt(x, y)
      return x + "," + y
    }
    function away(): string { keyCatcher.pointerGone(); return "away" }
    function state(): string {
      return JSON.stringify({ counts: root.counts, app: root.app, bots: root.bots.length })
    }
  }

  // ---------------------------------------------------------------- helpers
  function fmtAgo(ts) {
    if (!ts) return ""
    var s = Math.max(0, nowMs / 1000 - ts)
    if (s < 90) return "now"
    var m = Math.floor(s / 60)
    if (m < 60) return m + "m"
    var h = Math.floor(m / 60)
    if (h < 24) return h + "h"
    var d = Math.floor(h / 24)
    return d < 7 ? d + "d" : Math.floor(d / 7) + "w"
  }
  function noise(text) {
    var glyphs = "░▒▓█▓▒", h = 2166136261, out = ""
    for (var i = 0; i < text.length; i++) { h ^= text.charCodeAt(i); h = (h * 16777619) >>> 0 }
    for (var j = 0; j < text.length; j++) {
      h ^= h << 13; h >>>= 0; h ^= h >>> 17; h ^= h << 5; h >>>= 0
      out += glyphs.charAt(h % glyphs.length)
    }
    return out
  }
  function label(text) { text = String(text || ""); return scrub ? noise(text) : text }

  function moveCursor(delta) {
    if (botRows.length === 0) return
    var at = botRows.indexOf(cursor)
    if (at < 0) { cursor = botRows[0]; return }
    cursor = botRows[Math.max(0, Math.min(botRows.length - 1, at + delta))]
    ensureVisible()
  }
  function ensureVisible() {
    var item = repeater.itemAt(cursor)
    if (!item) return
    if (item.y < panelFlick.contentY) panelFlick.contentY = Math.max(0, item.y - Style.space(8))
    else if (item.y + item.height > panelFlick.contentY + panelFlick.height)
      panelFlick.contentY = Math.min(panelFlick.contentHeight - panelFlick.height,
                                     item.y + item.height - panelFlick.height + Style.space(8))
  }

  // ---------------------------------------------------------------- bar
  // In count mode: how many bots want you. Nothing when nobody does, so the
  // bar stays quiet; in avatars mode the faces say it instead.
  readonly property int wantingCount: wanting.length
  readonly property string barText: {
    if (!snap || vertical || barMetric !== "count") return ""
    return wantingCount > 0 ? String(wantingCount) : ""
  }
  readonly property string barTooltip: {
    if (!snap) return "Assistants"
    if (wanting.length === 0) return "Assistants · nobody waiting"
    return wanting.map(function(b) { return b.name }).join(", ") + " waiting on you"
  }

  implicitWidth: row.implicitWidth
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property real openPanelIndicatorWidth: row.width

  // What the bar draws beside the logo. Nothing waiting means nothing beside
  // it - the logo alone is still the widget, and still opens the panel.
  readonly property bool vertical: !!(bar && bar.vertical)
  readonly property var barAvatars: (!snap || vertical || barMetric !== "avatars")
    ? [] : wanting.slice(0, maxBarAvatars)
  // The glyphs beside it carry their own optical padding; a mark drawn to the
  // full icon canvas would stand taller than all of them.
  readonly property real markSize: Math.round(Style.bar.iconCanvas * 0.82)
  // How far the row pulls back into the icon slot's padding, to bring what
  // follows the mark close enough to read as part of it.
  readonly property real barPull: Style.space(3)
  // Same parity as the mark, so both round their centre to the same pixel -
  // otherwise the avatars sit half a pixel below it, which reads as crooked.
  readonly property real barAvatarSize: {
    var h = Math.round(Style.font.caption * 1.15)
    return (h % 2) === (markSize % 2) ? h : h + 1
  }

  Row {
    id: row
    anchors.centerIn: parent
    // The icon slot is wider than the mark drawn inside it, which leaves as
    // much air after the mark as there is between whole widgets. Pull back
    // into that padding so the mark and what follows read as one thing.
    spacing: -root.barPull

    // The Grok Bot mark, always. Drawn rather than loaded from the app icon so
    // it takes the bar's colours like every other widget instead of dropping a
    // dark tile into the theme, and outlined so it carries the same weight as
    // the line glyphs beside it. Dimmed when the app is not running.
    BarIconButton {
      id: button
      bar: root.bar
      text: "\u{f06a9}"
      onPressed: function(buttonCode) { root.barPressed(buttonCode) }
      iconComponent: Component {
        Item {
          Avatar {
            anchors.centerIn: parent
            width: root.markSize
            height: width
            shape: "squircle"
            outlined: true
            fill: root.bar ? root.bar.barForeground : root.fg
            eyeColor: root.bar ? root.bar.barForeground : root.fg
            face: "neutral"
          }
        }
      }
    }

    // To its right: the bots waiting on you, as themselves. Centred on the
    // button rather than on the row: the mark is centred in the button too, so
    // sharing that reference makes both round to the same pixel.
    Row {
      id: avatars
      anchors.verticalCenter: button.verticalCenter
      spacing: Style.space(3)
      visible: root.barAvatars.length > 0

      Repeater {
        model: root.barAvatars
        Avatar {
          id: barAvatar
          required property var modelData
          required property int index
          width: root.barAvatarSize
          height: root.barAvatarSize
          shape: modelData.shape
          image: root.avatarFor(modelData)
          fill: root.colorFor(modelData)
          eyeColor: root.eyeInk
          face: root.faceFor(modelData)

          // Look up when you come to open the panel. Each one waits a little
          // longer than the last, so it ripples along the row instead of
          // firing as one block.
          Connections {
            target: root
            function onBarGreeted() { greet.restart() }
          }
          Timer {
            id: greet
            interval: 30 + barAvatar.index * 90
            onTriggered: barAvatar.playBold(barAvatar.index + root.barGreetSeed)
          }
        }
      }
    }

    // Or, to its right: how many are waiting.
    Text {
      id: metric
      anchors.verticalCenter: button.verticalCenter
      visible: root.barText !== ""
      text: root.barText
      color: root.alarming ? root.urgent : (root.bar ? root.bar.barForeground : root.fg)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    // Close the widget with as much air as the icon slot opens it with, so
    // whatever is beside the mark is not left flush against the next widget.
    // The pull-back applies here too, so add it back or the tail comes up
    // short of the head.
    Item {
      height: 1
      width: (avatars.visible || metric.visible)
        ? Math.round((button.width - root.markSize) / 2) + root.barPull : 0
    }
  }

  MouseArea {
    anchors.fill: row
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: function(mouse) { root.barPressed(mouse.button) }
    onEntered: {
      if (root.bar) root.bar.showTooltip(row, root.barTooltip)
      root.barGreetSeed += 1
      root.barGreeted()
    }
    onExited: if (root.bar) root.bar.hideTooltip(row)
  }

  function barPressed(buttonCode) {
    if (buttonCode === Qt.RightButton) root.openBot(root.wanting[0] || root.bots[0])
    else if (buttonCode === Qt.MiddleButton) root.cycleBarMetric()
    else if (root.dropped !== "") root.dismiss(true)
    else root.toggle()
  }

  // ---------------------------------------------------------------- panel
  KeyboardPanel {
    id: panel
    anchorItem: row
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Number(root.setting("width", 480)))
    contentHeight: Math.min(root.dropHeight, panel.availableCardHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx < 0) root.scrub = !root.scrub
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.openCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r") root.cycleBarMetric()
        else if (t === "g" || t === "G") root.cycleOrdering()
      }

      // Where the pointer is, in panel coordinates. Avatars map it into their
      // own space and lean toward it; -1 means "not over the panel".
      property real pointerX: -1
      property real pointerY: -1

      function pointerAt(x, y) {
        pointerLeave.stop()
        pointerX = x
        pointerY = y
      }

      // Hover belongs to the topmost item, so crossing from a row onto a
      // separator - or between two rows - hands it over and reads as leaving.
      // Wait a moment before believing it: a real departure stays away, a
      // handover puts the pointer back within a frame or two, and the eyes
      // never snap forward for it.
      function pointerGone() { pointerLeave.restart() }

      Timer {
        id: pointerLeave
        interval: 260
        onTriggered: { keyCatcher.pointerX = -1; keyCatcher.pointerY = -1 }
      }

      MouseArea {
        id: pointerTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onPositionChanged: function(mouse) { keyCatcher.pointerAt(mouse.x, mouse.y) }
        onExited: keyCatcher.pointerGone()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + Style.space(8)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          x: Style.space(4)
          width: parent.width - Style.space(8)
          spacing: 0

          // ---- header
          Item {
            width: parent.width
            Text {
              anchors.right: parent.right
              text: "✕ close all"
              color: closeAllArea.containsMouse ? root.fg : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              MouseArea { id: closeAllArea; anchors.fill: parent; hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor; onClicked: root.closeChat("all") }
            }
            height: header.implicitHeight + Style.space(10)
            Column {
              id: header
              width: parent.width
              spacing: Style.space(2)
              Text {
                text: {
                  if (root.opening !== "") return "opening " + root.opening + "…"
                  if (!root.snap) return "starting…"
                  return "ASSISTANTS" + (root.services.indexOf("grok") < 0 ? ""
                    : root.app.running ? " · Grok Bot " + (root.app.version || "") : " · Grok Bot not running")
                }
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                visible: !!root.snap
                text: {
                  var c = root.counts
                  var bits = [root.bots.length + " assistants"]
                  if ((c.awaiting || 0) > 0) bits.push(c.awaiting + " waiting on you")
                  if ((c.working || 0) > 0) bits.push(c.working + " working")
                  if ((c.unread_messages || 0) > 0) bits.push(c.unread_messages + " unread")
                  if ((c.groups || 0) > 0) bits.push(c.groups + " group")
                  return bits.join(" · ")
                }
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: root.faint }

          // ---- rows
          Repeater {
            id: repeater
            model: root.rows

            Item {
              id: rowItem
              required property var modelData
              required property int index
              width: column.width
              height: modelData.kind === "section" ? Style.space(26)
                    : modelData.kind === "rule" ? Style.space(13) : Style.space(46)

              // The break between "wants you" and everyone else. At the same
              // weight as the section rules it was too quiet to do its job -
              // this is the one division in the list that carries meaning.
              Rectangle {
                visible: modelData.kind === "rule"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: root.divider
              }

              // Bots with news get greeted when the panel opens.
              readonly property bool wantsGreeting: modelData.kind === "bot"
                && (modelData.bot.unread > 0 || modelData.bot.awaiting)

              Connections {
                target: root
                function onGreetRequested(everyone) {
                  if (rowItem.modelData.kind !== "bot") return
                  if (everyone || rowItem.wantsGreeting) rowGreet.restart()
                }
              }
              // Staggered by position so the flourishes read as a wave.
              Timer {
                id: rowGreet
                interval: 60 + rowItem.index * 85
                onTriggered: if (rowAvatar) rowAvatar.play(root.nextFlourish())
              }

              // section header
              Text {
                visible: modelData.kind === "section"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(4)
                text: root.label(modelData.name).toUpperCase() + "  " + (modelData.count || "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // bot row
              Rectangle {
                visible: modelData.kind === "bot"
                anchors.fill: parent
                anchors.leftMargin: -Style.space(4)
                anchors.rightMargin: -Style.space(4)
                radius: Style.space(1.5)
                color: index === root.cursor ? root.hilite : "transparent"

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(9)

                  Avatar {
                    id: rowAvatar
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(28)
                    height: Style.space(28)
                    shape: modelData.kind === "bot" ? modelData.bot.shape : "blob"
                    image: modelData.kind === "bot" ? root.avatarFor(modelData.bot) : ""
                    fill: modelData.kind === "bot" ? root.colorFor(modelData.bot) : root.dim
                    eyeColor: root.eyeInk
                    face: modelData.kind === "bot" ? root.faceFor(modelData.bot) : "neutral"
                    Component.onCompleted: root.flourishCount = flourishCount

                    // Watch the pointer while it is over the panel. Every row
                    // maps the one shared position into its own coordinates, so
                    // the whole list looks at the same spot from where it sits.
                    readonly property point look: mapFromItem(keyCatcher,
                      keyCatcher.pointerX, keyCatcher.pointerY)
                    looking: keyCatcher.pointerX >= 0
                    followX: look.x
                    followY: look.y

                    // Just read, or just answered: take a bow.
                    property bool wasWanted: false
                    onFaceChanged: {
                      var wants = face === "attentive" || face === "excited" || face === "curious"
                      if (wants) wasWanted = true
                      else if (wasWanted) { wasWanted = false; celebrate() }
                    }
                  }

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(28) - Style.space(9) - badge.width - Style.space(9)
                    spacing: Style.space(1)

                    Row {
                      spacing: Style.space(5)
                      width: parent.width
                      Text {
                        text: modelData.kind === "bot" ? root.label(modelData.bot.name) : ""
                        color: modelData.kind === "bot" && modelData.bot.focused ? root.accent : root.fg
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: modelData.kind === "bot" && (modelData.bot.awaiting || modelData.bot.unread > 0)
                      }
                      Text {
                        text: modelData.kind === "bot"
                          ? (modelData.bot.is_group ? "group of " + modelData.bot.members
                                                    : root.label(modelData.bot.title))
                          : ""
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: Math.max(0, parent.width - Style.space(120))
                      }
                    }

                    Text {
                      width: parent.width
                      text: modelData.kind === "bot"
                        ? (modelData.bot.working ? "thinking…" : root.label(modelData.bot.last_text))
                        : ""
                      // Full foreground for the ones waiting on you, dimmed for
                      // the rest: weight carries it, so nothing has to shout.
                      color: modelData.kind === "bot" && modelData.bot.awaiting ? root.fg
                             : (modelData.kind === "bot" && modelData.bot.working ? root.accent : root.dim)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }

                  Column {
                    id: badge
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(38)
                    spacing: Style.space(2)

                    Text {
                      anchors.right: parent.right
                      text: modelData.kind === "bot" ? root.fmtAgo(modelData.bot.last_activity_ts) : ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Rectangle {
                      anchors.right: parent.right
                      visible: modelData.kind === "bot" && modelData.bot.unread > 0
                      width: Math.max(Style.space(14), unreadText.implicitWidth + Style.space(6))
                      height: Style.space(14)
                      radius: height / 2
                      color: root.accent
                      Text {
                        id: unreadText
                        anchors.centerIn: parent
                        text: modelData.kind === "bot" ? String(modelData.bot.unread) : ""
                        color: Color.background
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: {
                    root.cursor = index
                    var e = mapToItem(keyCatcher, mouseX, mouseY)
                    keyCatcher.pointerAt(e.x, e.y)
                  }
                  onExited: keyCatcher.pointerGone()
                  onClicked: root.openBot(modelData.bot)
                  // Hover goes to the topmost item, so a row would otherwise
                  // starve the panel-wide tracker and the eyes would freeze
                  // exactly when you are looking at them.
                  onPositionChanged: function(mouse) {
                    var p = mapToItem(keyCatcher, mouse.x, mouse.y)
                    keyCatcher.pointerAt(p.x, p.y)
                  }
                }

                // Pop out / close, on the hovered row, over the time column.
                Row {
                  visible: modelData.kind === "bot" && index === root.cursor
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(10)
                  Repeater {
                    model: [["\u{f03cb}", "popout"], ["✕", "close"]]
                    Text {
                      required property var modelData
                      text: modelData[0]
                      color: rowBtn.containsMouse ? root.fg : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      MouseArea {
                        id: rowBtn
                        anchors.fill: parent
                        anchors.margins: -Style.space(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData[1] === "popout" ? root.popOut(rowItem.modelData.bot.service)
                                                             : root.closeChat(rowItem.modelData.bot.service)
                      }
                    }
                  }
                }
              }
            }
          }

          // ---- empty states
          Text {
            visible: root.snap && root.bots.length === 0
            width: parent.width
            topPadding: Style.space(10)
            text: "no assistants enabled; set services to muse,dots,grok"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Rectangle { width: parent.width; height: 1; color: root.faint; visible: root.bots.length > 0 }

          // ---- footer
          Item {
            width: parent.width
            height: Style.space(30)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "j/k move · ⏎ open · g " + root.ordering
                    + " · h hide · r beside logo: " + root.barMetric
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
