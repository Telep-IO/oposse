import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Bar entry for one service (muse, dots, grok). Click → bin/drop-toggle drops its
// window down from the bar (Hyprland special workspace named after it). While down,
// a small tab hangs off its bottom-right corner to pop it out into a window.
BarWidget {
  id: root
  moduleName: "telep.drops"

  // Dropdown geometry, monitor-local. Handed to bin/drop-toggle on every click.
  readonly property int dropWidth: Number(setting("width", 480))
  readonly property int dropHeight: Math.round((screen ? screen.height : 1200) * Number(setting("heightPercent", 60)) / 100)
  readonly property int dropTop: (bar && bar.position === "top" ? barSize : 0) + Style.space(8)
  readonly property string service: String(setting("service", "muse"))
  readonly property string url: String(setting("url", ""))
  readonly property string avatar: String(setting("avatar", ""))

  readonly property var screen: QsWindow.window ? QsWindow.window.screen : null
  readonly property string toggleBin: Qt.resolvedUrl("bin/drop-toggle").toString().replace("file://", "")
  property bool dropped: false
  property int centerX: 0

  function toggle() {
    centerX = Math.round(button.mapToItem(null, button.width / 2, 0).x)
    Quickshell.execDetached([toggleBin, service, String(centerX), String(dropTop), String(dropWidth), String(dropHeight), url])
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activespecial") return
      var parts = event.data.split(",")
      if (root.screen && parts[1] === root.screen.name) root.dropped = parts[0] === "special:" + root.service
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: icon.width + 2 * scaledHorizontalMargin
    hasVisualContent: true
    tooltipText: ({ muse: "Muse", dots: "Dots", grok: "Grok Bot" })[root.service] || root.service
    onPressed: root.toggle()

    Image {
      id: icon
      anchors.centerIn: parent
      width: Math.round(button.barSize * 0.75)
      height: width
      smooth: true
      mipmap: true
      source: root.avatar !== "" ? "file://" + root.avatar.replace(/^~/, Quickshell.env("HOME")) : Qt.resolvedUrl("icons/" + root.service + ".png")
    }
  }

  PanelWindow {
    id: popTab
    visible: root.dropped && root.screen !== null
    screen: root.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "telep-drops-popout"
    anchors { top: true; left: true }
    implicitWidth: tabLabel.implicitWidth + Style.space(20)
    implicitHeight: tabLabel.implicitHeight + Style.space(10)
    margins {
      left: Math.max(0, Math.min((root.screen ? root.screen.width : 0) - root.dropWidth, root.centerX - root.dropWidth / 2)) + root.dropWidth - implicitWidth
      top: root.dropTop + root.dropHeight + Style.space(4)
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      color: root.bar ? root.bar.background : Color.background
      border.width: 1
      border.color: Qt.darker(tabLabel.color, 2)

      Text {
        id: tabLabel
        anchors.centerIn: parent
        text: "󰏋  pop out"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([root.toggleBin, root.service, "popout"])
      }
    }
  }
}
