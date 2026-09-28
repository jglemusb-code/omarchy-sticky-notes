import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Palette.js" as Palette

// Sticky notes host. Owns the note list, persists it to disk, and creates one
// Note surface per entry. Notes sit on the desktop layer (behind windows)
// until they are raised to the front.
//
// Shell API (keepLoaded panel):
//   summon '{"action":"new"}'   create a note (and raise notes to the front)
//   summon '{"action":"front"}' / summon ''   raise notes in front of windows
//   summon '{"action":"back"}'  / hide        send notes back to the desktop
//   toggle                      flip between front and desktop
Item {
  id: root

  // Injected by the shell; unused but declared so the host can hand them over.
  property var shell: null
  property var manifest: null

  // "opened" is what the shell's toggle() inspects: raised in front of windows.
  property bool raised: false
  readonly property bool opened: raised

  readonly property string dataDir: {
    var xdg = Quickshell.env("XDG_DATA_HOME")
    return (xdg && xdg.length > 0 ? xdg : Quickshell.env("HOME") + "/.local/share")
  }
  readonly property string dataPath: dataDir + "/omarchy-sticky-notes.json"

  property bool loaded: false
  // Id of the note that should grab keyboard focus once its surface maps.
  property string focusNoteId: ""

  ListModel { id: notesModel }

  function open(payloadJson) {
    var action = ""
    try { action = (JSON.parse(payloadJson || "{}").action || "") } catch (e) {}
    if (action === "new") newNote()
    else if (action === "back") raised = false
    else raised = true
  }

  function close() { raised = false }

  function indexOfNote(noteId) {
    for (var i = 0; i < notesModel.count; i++)
      if (notesModel.get(i).noteId === noteId) return i
    return -1
  }

  function screenFor(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  function newNote(nearNoteId) {
    var w = 300, h = 300
    var screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    var px, py, tint = Palette.defaultTint
    var near = nearNoteId ? indexOfNote(nearNoteId) : -1

    if (near >= 0) {
      // Spawned from a note's "+" button: open next to it, like Windows does.
      var src = notesModel.get(near)
      screenName = src.screenName
      tint = src.tint
      px = src.px + 30
      py = src.py + 30
    } else {
      var screen = screenFor(screenName)
      var sw = screen ? screen.width : 1920
      // Cascade new notes from the top-right so they don't stack exactly.
      var offset = (notesModel.count % 8) * 30
      px = Math.max(0, sw - w - 60 - offset)
      py = 80 + offset
    }

    var id = Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36)
    notesModel.append({ noteId: id, body: "", tint: tint, px: px, py: py, pw: w, ph: h, screenName: screenName })
    focusNoteId = id
    raised = true
    scheduleSave()
  }

  function removeNote(noteId) {
    var i = indexOfNote(noteId)
    if (i < 0) return
    notesModel.remove(i)
    scheduleSave()
  }

  function updateNote(noteId, fields) {
    var i = indexOfNote(noteId)
    if (i < 0) return
    for (var k in fields) notesModel.setProperty(i, k, fields[k])
    scheduleSave()
  }

  function load(raw) {
    if (loaded) return
    notesModel.clear()
    try {
      var data = JSON.parse(raw || "{}")
      var list = Array.isArray(data.notes) ? data.notes : []
      for (var i = 0; i < list.length; i++) {
        var n = list[i]
        if (!n || !n.id) continue
        notesModel.append({
          noteId: String(n.id),
          body: String(n.text || ""),
          tint: Palette.has(n.color) ? n.color : Palette.defaultTint,
          px: Number(n.x) || 0,
          py: Number(n.y) || 0,
          pw: Math.max(Palette.minWidth, Number(n.width) || 300),
          ph: Math.max(Palette.minHeight, Number(n.height) || 300),
          screenName: String(n.screen || "")
        })
      }
    } catch (e) {
      console.warn("sticky-notes: could not parse " + dataPath + ":", e)
    }
    loaded = true
  }

  function serialize() {
    var out = []
    for (var i = 0; i < notesModel.count; i++) {
      var n = notesModel.get(i)
      out.push({ id: n.noteId, text: n.body, color: n.tint, x: n.px, y: n.py,
                 width: n.pw, height: n.ph, screen: n.screenName })
    }
    return JSON.stringify({ version: 1, notes: out }, null, 2) + "\n"
  }

  function scheduleSave() { if (loaded) saveTimer.restart() }

  function saveNow() {
    if (!loaded) return
    saveTimer.stop()
    notesFile.setText(serialize())
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: root.saveNow()
  }

  FileView {
    id: notesFile
    path: root.dataPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    // First run: no file yet, start with an empty board.
    onLoadFailed: root.load("")
  }

  // Flush pending edits when the shell reloads the plugin or exits.
  Component.onDestruction: if (saveTimer.running) saveNow()

  Instantiator {
    model: notesModel
    delegate: Note {
      host: root
      raised: root.raised
      targetScreen: root.screenFor(screenName)
    }
  }
}
