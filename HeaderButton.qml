import QtQuick
import qs.Commons

// Flat text button for the note header.
Rectangle {
  id: button

  property string label: ""
  property color textColor: "#202020"
  signal clicked()

  width: Math.max(26, labelText.implicitWidth + 12)
  height: 26
  radius: Math.min(Style.cornerRadius, 4)
  color: mouse.containsMouse ? Util.alpha(textColor, mouse.pressed ? 0.18 : 0.1) : "transparent"

  Text {
    id: labelText
    anchors.centerIn: parent
    text: button.label
    color: button.textColor
    font.family: Style.font.family
    font.pixelSize: 15
    font.bold: true
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
