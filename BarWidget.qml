import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "workspace-gesture-switcher"
  property bool enabled: true
  property bool configured: false
  property int distance: 80
  property real cancelRatio: 0.20
  property int minSpeed: 10
  property bool createNew: true
  property bool forever: false
  readonly property string helper: Qt.resolvedUrl("bin/gesture-control").toString().replace(/^file:\/\//, "")
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function apply(key, value) {
    if (setProcess.running) return
    setProcess.command = [helper, "set", key, String(value)]
    setProcess.running = true
  }

  function load(data) {
    configured = data.configured === true
    enabled = data.enabled === true
    distance = Number(data.distance)
    cancelRatio = Number(data.cancelRatio)
    minSpeed = Number(data.minSpeed)
    createNew = data.createNew === true
    forever = data.forever === true
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  Component.onCompleted: refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  Process {
    id: statusProcess
    command: [root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.load(JSON.parse(text)) } catch (error) { console.warn("Gesture status:", error) }
      }
    }
  }
  Process {
    id: setProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.load(JSON.parse(text)); refreshTimer.start() } catch (error) { console.warn("Gesture update:", text) }
      }
    }
  }
  Timer { id: refreshTimer; interval: 150; repeat: false; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰥸"
    active: root.enabled
    tooltipText: !root.configured ? "Workspace Gesture Switcher needs setup" : (root.enabled ? "Workspace Gesture Switcher enabled" : "Workspace Gesture Switcher disabled")
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.toggle()
    }
  }
}
