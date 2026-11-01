import Foundation

// Compatibility entry point: keep all platforms on the same vector design.
// Run from the project root. The shared renderer also refreshes the SVG master.
let renderer = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  .appendingPathComponent("branding/generate_app_icons.swift")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["swift", renderer.path]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
