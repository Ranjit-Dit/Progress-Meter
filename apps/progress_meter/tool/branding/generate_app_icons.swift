import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// A single vector definition generates the SVG master and every native icon.
// Run from the project root: swift tool/branding/generate_app_icons.swift
enum Segment {
  case move(Double, Double)
  case line(Double, Double)
  case curve(Double, Double, Double, Double, Double, Double)
}

struct Stroke {
  let segments: [Segment]
  let color: String
  let opacity: Double
  let width: Double

  var svgPath: String {
    segments.map { segment in
      switch segment {
      case let .move(x, y): return "M\(x) \(y)"
      case let .line(x, y): return "L\(x) \(y)"
      case let .curve(a, b, c, d, x, y): return "C\(a) \(b) \(c) \(d) \(x) \(y)"
      }
    }.joined(separator: " ")
  }

  var path: CGPath {
    let path = CGMutablePath()
    for segment in segments {
      switch segment {
      case let .move(x, y): path.move(to: CGPoint(x: x, y: y))
      case let .line(x, y): path.addLine(to: CGPoint(x: x, y: y))
      case let .curve(a, b, c, d, x, y):
        path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: a, y: b), control2: CGPoint(x: c, y: d))
      }
    }
    return path
  }
}

let strokes = [
  Stroke(segments: [
    .move(249, 664), .curve(222, 618, 208, 566, 208, 512),
    .curve(208, 344, 344, 208, 512, 208),
    .curve(680, 208, 816, 344, 816, 512),
    .curve(816, 566, 802, 618, 775, 664)
  ], color: "9DBA9B", opacity: 0.34, width: 58),
  Stroke(segments: [
    .move(249, 664), .curve(222, 618, 208, 566, 208, 512),
    .curve(208, 344, 344, 208, 512, 208),
    .curve(648, 208, 754, 296, 794, 410)
  ], color: "F4F6E8", opacity: 1, width: 58),
  Stroke(segments: [.move(352, 650), .line(468, 532), .line(558, 594), .line(700, 424)],
         color: "F4F6E8", opacity: 1, width: 64)
]

func color(_ hex: String, alpha: Double = 1) -> CGColor {
  let rgb = UInt32(hex, radix: 16)!
  return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
    CGFloat((rgb >> 16) & 255) / 255, CGFloat((rgb >> 8) & 255) / 255,
    CGFloat(rgb & 255) / 255, CGFloat(alpha)
  ])!
}

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let branding = project.appendingPathComponent("assets/branding")
try FileManager.default.createDirectory(at: branding, withIntermediateDirectories: true)
let svgStrokes = strokes.map {
  "  <path d=\"\($0.svgPath)\" fill=\"none\" stroke=\"#\($0.color)\" stroke-opacity=\"\($0.opacity)\" stroke-width=\"\($0.width)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
}.joined(separator: "\n")
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title description">
  <title id="title">Progress Meter</title>
  <desc id="description">A cream progress gauge and rising learning path on forest green, ending in a lime milestone.</desc>
  <defs><linearGradient id="background" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#367C62"/><stop offset="1" stop-color="#173C30"/></linearGradient></defs>
  <rect width="1024" height="1024" fill="url(#background)"/>
\(svgStrokes)
  <circle cx="700" cy="424" r="38" fill="#D0E49E"/>
</svg>
"""
try svg.write(to: branding.appendingPathComponent("progress-meter.svg"), atomically: true, encoding: .utf8)

func render(pixels: Int, rounded: Bool, destination: URL) throws {
  // iOS/marketing output uses a true RGB PNG with no alpha channel.
  let alpha = rounded ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
  let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                          bytesPerRow: pixels * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: alpha.rawValue)!
  context.translateBy(x: 0, y: CGFloat(pixels))
  context.scaleBy(x: CGFloat(pixels) / 1024, y: -CGFloat(pixels) / 1024)
  if rounded {
    context.addPath(CGPath(roundedRect: CGRect(x: 44, y: 44, width: 936, height: 936),
                           cornerWidth: 218, cornerHeight: 218, transform: nil))
    context.clip()
  }
  let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                            colors: [color("367C62"), color("173C30")] as CFArray,
                            locations: [0, 1])!
  context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1024, y: 1024),
                             options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  for stroke in strokes {
    context.addPath(stroke.path)
    context.setStrokeColor(color(stroke.color, alpha: stroke.opacity))
    context.setLineWidth(stroke.width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
  }
  context.setFillColor(color("D0E49E"))
  context.fillEllipse(in: CGRect(x: 662, y: 386, width: 76, height: 76))
  let image = context.makeImage()!
  let writer = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(writer, image, nil)
  guard CGImageDestinationFinalize(writer) else { throw CocoaError(.fileWriteUnknown) }
}

func catalog(_ relative: String, rounded: Bool) throws -> Int {
  let directory = project.appendingPathComponent(relative)
  let data = try Data(contentsOf: directory.appendingPathComponent("Contents.json"))
  let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
  let images = catalog["images"] as! [[String: Any]]
  var rendered = Set<String>()
  for item in images {
    guard let filename = item["filename"] as? String, rendered.insert(filename).inserted else { continue }
    let size = Double((item["size"] as! String).split(separator: "x")[0])!
    let scale = Double((item["scale"] as! String).dropLast())!
    try render(pixels: Int(size * scale), rounded: rounded, destination: directory.appendingPathComponent(filename))
  }
  return rendered.count
}

let ios = try catalog("ios/Runner/Assets.xcassets/AppIcon.appiconset", rounded: false)
let macos = try catalog("macos/Runner/Assets.xcassets/AppIcon.appiconset", rounded: true)
for (density, pixels) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
  try render(pixels: pixels, rounded: true,
             destination: project.appendingPathComponent("android/app/src/main/res/mipmap-\(density)/ic_launcher.png"))
}
try render(pixels: 1024, rounded: false, destination: branding.appendingPathComponent("progress-meter.png"))
print("Generated Progress Meter icons: \(ios) iOS, \(macos) macOS, 5 Android, SVG master, and PNG preview.")
