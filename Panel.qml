import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "workspace-gesture-switcher"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null

  function toggleEnabled() { if (hostWidget) hostWidget.apply("enabled", !hostWidget.enabled) }
  function change(key, value) { if (hostWidget) hostWidget.apply(key, value) }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(12)
        Text { text: "󰥸"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.display }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text { text: "Workspace Gesture Switcher"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
          Text { text: hostWidget && hostWidget.enabled ? "Workspace switching enabled" : "Workspace switching disabled"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
        }
      }

      PanelSeparator { foreground: root.bar.foreground }
      Button {
        width: parent.width
        iconText: hostWidget && hostWidget.enabled ? "󰄬" : "󰅖"
        text: hostWidget && hostWidget.enabled ? "Enabled — turn off" : "Disabled — turn on"
        foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; fontSize: Style.font.bodySmall
        bordered: true; active: hostWidget && hostWidget.enabled
        onClicked: root.toggleEnabled()
      }

      PanelSectionHeader { text: "SENSITIVITY"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
      SettingRow {
        label: "Trigger distance"; value: hostWidget ? hostWidget.distance : 80; suffix: "px"
        hint: "Lower = triggers earlier"
        onDecreaseRequested: root.change("distance", Math.max(20, (hostWidget ? hostWidget.distance : 80) - 10))
        onIncreaseRequested: root.change("distance", Math.min(800, (hostWidget ? hostWidget.distance : 80) + 10))
      }
      SettingRow {
        label: "Minimum speed"; value: hostWidget ? hostWidget.minSpeed : 10; suffix: ""
        hint: "Lower = slow swipes count"
        onDecreaseRequested: root.change("minSpeed", Math.max(0, (hostWidget ? hostWidget.minSpeed : 10) - 5))
        onIncreaseRequested: root.change("minSpeed", Math.min(100, (hostWidget ? hostWidget.minSpeed : 10) + 5))
      }
      SettingRow {
        label: "Cancel threshold"; value: hostWidget ? Math.round(hostWidget.cancelRatio * 100) : 20; suffix: "%"
        hint: "Lower = short swipes succeed more easily"
        onDecreaseRequested: root.change("cancelRatio", Math.max(0.05, (hostWidget ? hostWidget.cancelRatio : 0.20) - 0.05).toFixed(2))
        onIncreaseRequested: root.change("cancelRatio", Math.min(0.95, (hostWidget ? hostWidget.cancelRatio : 0.20) + 0.05).toFixed(2))
      }

      PanelSectionHeader { text: "WORKSPACES"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
      ToggleRow {
        text: "Create workspace at edge"; checked: hostWidget && hostWidget.createNew
        onClicked: root.change("createNew", !(hostWidget && hostWidget.createNew))
      }
      ToggleRow {
        text: "Wrap around at the end"; checked: hostWidget && hostWidget.forever
        onClicked: root.change("forever", !(hostWidget && hostWidget.forever))
      }
    }
  }

  component SettingRow: Column {
    property string label: ""
    property var value: 0
    property string suffix: ""
    property string hint: ""
    signal decreaseRequested()
    signal increaseRequested()
    width: parent.width
    spacing: Style.space(3)
    Row {
      width: parent.width; spacing: Style.space(6)
      Text { width: parent.width - decrease.width - increase.width - valueText.width - parent.spacing * 3; anchors.verticalCenter: parent.verticalCenter; text: label; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
      Button { id: decrease; width: Style.space(38); text: "−"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; bordered: true; onClicked: decreaseRequested() }
      Text { id: valueText; width: Style.space(62); anchors.verticalCenter: parent.verticalCenter; text: value + suffix; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignHCenter }
      Button { id: increase; width: Style.space(38); text: "+"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; bordered: true; onClicked: increaseRequested() }
    }
    Text { width: parent.width; text: hint; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
  }

  component ToggleRow: Button {
    property bool checked: false
    width: parent.width
    iconText: checked ? "󰄬" : "󰅖"
    foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; fontSize: Style.font.bodySmall
    bordered: true; active: checked
  }
}
