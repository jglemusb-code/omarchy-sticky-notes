import QtQuick
import Quickshell
import Quickshell.Wayland

// One transparent, full-screen surface per monitor that draws that monitor's
// notes. The surface itself never moves, so dragging a note is a plain item
// move that tracks the pointer exactly. Only the notes accept input: the mask
// is the union of their rectangles, and clicks anywhere else fall through.
PanelWindow {
  id: board

  required property var modelData
  property var host: null

  property var noteRegions: []
  readonly property bool hasNotes: noteRegions.length > 0

  screen: modelData
  visible: hasNotes
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }

  WlrLayershell.namespace: "omarchy-sticky-notes"
  // Desktop layer by default so notes stay behind your windows; Top when raised.
  WlrLayershell.layer: host && host.raised ? WlrLayer.Top : WlrLayer.Bottom
  // A freshly created note grabs the keyboard so you can type right away; it
  // hands the grab back (OnDemand) as soon as it has focus.
  WlrLayershell.keyboardFocus: host && host.focusNoteId !== "" && host.focusScreenName === modelData.name
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

  mask: Region { regions: board.noteRegions }

  function rebuildRegions() {
    var out = []
    for (var i = 0; i < notesRepeater.count; i++) {
      var item = notesRepeater.itemAt(i)
      if (item && item.onScreen) out.push(item.inputRegion)
    }
    noteRegions = out
  }

  Item {
    id: noteArea
    anchors.fill: parent

    Repeater {
      id: notesRepeater
      model: board.host ? board.host.notes : null

      delegate: Note {
        host: board.host
        area: noteArea
        onScreen: board.host.resolvedScreenName(screenName) === board.modelData.name
        onOnScreenChanged: Qt.callLater(board.rebuildRegions)
      }

      onItemAdded: Qt.callLater(board.rebuildRegions)
      onItemRemoved: Qt.callLater(board.rebuildRegions)
    }
  }
}
