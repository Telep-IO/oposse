// Eye finder check: qml6 tests/eyes.qml (exit 0 = pass). The bundled Dots
// picture has eyes where they were measured by hand; the Muse logo has none.
import QtQuick
import ".."

Window {
  width: 200; height: 100; visible: true
  property int pending: 2
  property var fails: []
  function done(name, ok) {
    if (!ok) fails.push(name)
    if (--pending === 0) { console.log(fails.length ? "FAIL " + fails : "ok"); Qt.exit(fails.length ? 1 : 0) }
  }
  function near(a, b) { return a.length === 6 && b.every(function(v, i) { return Math.abs(a[i] - v) < 0.03 }) }
  Avatar {
    id: dots
    width: 96; height: 96; detectEyes: true
    image: Qt.resolvedUrl("../icons/dots.png")
    onFoundEyesChanged: if (foundEyes.length) done("dots", near(foundEyes, [0.37, 0.53, 0.667, 0.53, 0.21, 0.11]))
  }
  Avatar {
    x: 100; width: 96; height: 96; detectEyes: true
    image: Qt.resolvedUrl("../icons/muse.png")
    onProbePixelsChanged: if (probePixels) done("muse logo", foundEyes.length === 0)
  }
  Timer { interval: 5000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.exit(1) } }
}
