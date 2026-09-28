.pragma library

// Note colors, modeled on the Windows Sticky Notes palette. "theme" follows
// the active Omarchy theme and is resolved in Note.qml from qs.Commons.Color.
var order = ["yellow", "green", "pink", "purple", "blue", "gray", "charcoal", "theme"]

var colors = {
  yellow:   { body: "#fff7d1", header: "#fff2ab", text: "#202020" },
  green:    { body: "#e4f9e0", header: "#cbf1c4", text: "#202020" },
  pink:     { body: "#ffe4f1", header: "#ffcce5", text: "#202020" },
  purple:   { body: "#f2e6ff", header: "#e7cfff", text: "#202020" },
  blue:     { body: "#e2f1ff", header: "#cde9ff", text: "#202020" },
  gray:     { body: "#f3f2f1", header: "#e0e0e0", text: "#202020" },
  charcoal: { body: "#454545", header: "#2f2f2f", text: "#f3f3f3" }
}

var defaultTint = "yellow"
var minWidth = 180
var minHeight = 120

function has(name) {
  return order.indexOf(name) !== -1
}
