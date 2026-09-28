import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Palette.js" as Palette

// One sticky note: its own layer-shell surface, positioned with margins from
// the top-left corner of its screen. Drag the header to move it, drag the
// bottom-right corner to resize it.
PanelWindow {
  id: note

  // Model roles, delivered by the Instantiator in StickyNotes.qml.
  required property int index
  required property string noteId
  required property string body
  required property string tint
  required property real px
  required property real py
  required property real pw
  required property real ph
  required property string screenName

  property var host: null
  property bool raised: false
  property var targetScreen: null

  // Live geometry while dragging/resizing; committed to the model on release.
  property real liveX: px
  property real liveY: py
  property real liveW: pw
  property real liveH: ph

  property bool confirmingDelete: false
  property bool pickingColor: false

  readonly property int headerHeight: 32
  readonly property var colors: tint === "theme"
    ? { body: Color.background, header: Util.alpha(Color.accent, 0.35), text: Color.foreground }
    : Palette.colors[tint] || Palette.colors[Palette.defaultTint]
  readonly property bool wantsFocus: host && host.focusNoteId === noteId

  screen: targetScreen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; left: true }
  margins { top: Math.round(liveY); left: Math.round(liveX) }
  implicitWidth: Math.round(liveW)
  implicitHeight: Math.round(liveH)

  WlrLayershell.namespace: "omarchy-sticky-notes"
  // Desktop layer by default so notes stay behind your windows; Top when raised.
  WlrLayershell.layer: raised ? WlrLayer.Top : WlrLayer.Bottom
  // A freshly created note grabs the keyboard so you can type right away; it
  // hands the grab back (OnDemand) as soon as it has focus.
  WlrLayershell.keyboardFocus: wantsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

  onPxChanged: liveX = px
  onPyChanged: liveY = py
  onPwChanged: liveW = pw
  onPhChanged: liveH = ph

  onWantsFocusChanged: if (wantsFocus) focusTimer.restart()
  Component.onCompleted: if (wantsFocus) focusTimer.restart()

  Timer {
    id: focusTimer
    interval: 60
    onTriggered: {
      editor.forceActiveFocus()
      editor.cursorPosition = editor.length
      releaseTimer.restart()
    }
  }

  Timer {
    id: releaseTimer
    interval: 400
    onTriggered: if (note.host && note.host.focusNoteId === note.noteId) note.host.focusNoteId = ""
  }

  Timer {
    id: confirmTimer
    interval: 3000
    onTriggered: note.confirmingDelete = false
  }

  function clampX(v) {
    var sw = targetScreen ? targetScreen.width : 10000
    return Math.max(0, Math.min(v, sw - liveW))
  }

  function clampY(v) {
    var sh = targetScreen ? targetScreen.height : 10000
    return Math.max(0, Math.min(v, sh - headerHeight))
  }

  function commitGeometry() {
    if (host) host.updateNote(noteId, { px: Math.round(liveX), py: Math.round(liveY),
                                        pw: Math.round(liveW), ph: Math.round(liveH) })
  }

  function requestDelete() {
    if (editor.text.trim().length === 0 || confirmingDelete) {
      if (host) host.removeNote(noteId)
      return
    }
    confirmingDelete = true
    confirmTimer.restart()
  }

  Rectangle {
    id: card
    anchors.fill: parent
    color: note.colors.body
    radius: Style.cornerRadius
    border.width: 1
    border.color: Qt.darker(note.colors.header, 1.15)
    clip: true

    // ------------------------------------------------------------ header
    Rectangle {
      id: header
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: note.headerHeight
      color: note.colors.header
      radius: card.radius

      // Square off the header's bottom corners.
      Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.radius
        color: parent.color
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real pressX: 0
        property real pressY: 0
        onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
        onPositionChanged: function(mouse) {
          if (!pressed) return
          // The surface moves under the pointer, so the offset from the
          // original grab point is the distance still left to travel.
          note.liveX = note.clampX(note.liveX + mouse.x - pressX)
          note.liveY = note.clampY(note.liveY + mouse.y - pressY)
        }
        onReleased: note.commitGeometry()
      }

      Row {
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        HeaderButton {
          label: "+"
          textColor: note.colors.text
          onClicked: if (note.host) note.host.newNote(note.noteId)
        }
      }

      Row {
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 2
        HeaderButton {
          label: "•••"
          textColor: note.colors.text
          onClicked: note.pickingColor = !note.pickingColor
        }
        HeaderButton {
          label: note.confirmingDelete ? "Delete?" : "×"
          textColor: note.confirmingDelete ? Color.urgent : note.colors.text
          onClicked: note.requestDelete()
        }
      }
    }

    // ------------------------------------------------------ color picker
    Row {
      id: colorPicker
      visible: note.pickingColor
      anchors { top: header.bottom; left: parent.left; right: parent.right }
      height: visible ? 28 : 0
      z: 2

      Repeater {
        model: Palette.order
        Rectangle {
          required property string modelData
          width: colorPicker.width / Palette.order.length
          height: colorPicker.height
          color: modelData === "theme" ? Color.background : Palette.colors[modelData].header
          border.width: note.tint === modelData ? 2 : 0
          border.color: modelData === "theme" ? Color.accent : note.colors.text

          Text {
            visible: modelData === "theme"
            anchors.centerIn: parent
            text: "◐"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: 14
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              note.pickingColor = false
              if (note.host) note.host.updateNote(note.noteId, { tint: parent.modelData })
            }
          }
        }
      }
    }

    // ------------------------------------------------------------ editor
    Flickable {
      id: flick
      anchors {
        top: colorPicker.visible ? colorPicker.bottom : header.bottom
        left: parent.left; right: parent.right; bottom: parent.bottom
        margins: 12
        bottomMargin: 16
      }
      contentWidth: width
      contentHeight: editor.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      function ensureVisible(r) {
        if (contentY >= r.y) contentY = r.y
        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
      }

      TextEdit {
        id: editor
        width: flick.width
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        persistentSelection: true
        color: note.colors.text
        selectionColor: Util.alpha(note.colors.text, 0.25)
        selectedTextColor: note.colors.text
        font.family: Style.font.family
        font.pixelSize: 15
        textFormat: TextEdit.PlainText
        Component.onCompleted: text = note.body
        onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
        onTextChanged: {
          if (text !== note.body && note.host) note.host.updateNote(note.noteId, { body: text })
        }

        Keys.onPressed: function(event) {
          if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
            if (note.host) note.host.newNote(note.noteId)
            event.accepted = true
          }
        }

        Text {
          visible: editor.text.length === 0
          text: "Take a note…"
          color: Util.alpha(note.colors.text, 0.45)
          font: editor.font
        }
      }
    }

    // ------------------------------------------------------ resize handle
    MouseArea {
      id: resizeArea
      width: 18
      height: 18
      anchors { right: parent.right; bottom: parent.bottom }
      cursorShape: Qt.SizeFDiagCursor
      property real pressX: 0
      property real pressY: 0
      onPressed: function(mouse) { pressX = mouse.x; pressY = mouse.y }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        note.liveW = Math.max(Palette.minWidth, note.liveW + mouse.x - pressX)
        note.liveH = Math.max(Palette.minHeight, note.liveH + mouse.y - pressY)
      }
      onReleased: note.commitGeometry()

      Text {
        anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
        text: "◢"
        color: Util.alpha(note.colors.text, 0.3)
        font.pixelSize: 10
      }
    }
  }
}
