import Cocoa
import FlutterMacOS
import ImageIO
import PDFKit
import Vision
import UserNotifications

class MainFlutterWindow: NSWindow {
  private var documentChannel: FlutterMethodChannel?
  private var reminderBridge: LocalReminderBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1440, height: 960))
    self.minSize = NSSize(width: 440, height: 680)
    self.center()
    RegisterGeneratedPlugins(registry: flutterViewController)
    reminderBridge = LocalReminderBridge(messenger: flutterViewController.engine.binaryMessenger)

    let channel = FlutterMethodChannel(
      name: "progress_meter/document_reader",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    documentChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "readDocument" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let bytes = arguments["bytes"] as? FlutterStandardTypedData,
            let name = arguments["name"] as? String else {
        result(FlutterError(code: "invalid_document", message: "Choose a PDF or image to read.", details: nil))
        return
      }
      let data = bytes.data
      LocalDocumentReader.queue.async {
        do {
          let payload = try LocalDocumentReader.read(data, name: name)
          DispatchQueue.main.async { result(payload) }
        } catch let failure as DocumentReadFailure {
          DispatchQueue.main.async {
            result(FlutterError(code: failure.code, message: failure.message, details: nil))
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "document_unreadable", message: "This document could not be read. Try a clearer image or an unlocked PDF.", details: nil))
          }
        }
      }
    }
    super.awakeFromNib()
  }
}

// Local reminders use macOS scheduling; no server or running Dart timer is needed.
private final class LocalReminderBridge: NSObject, UNUserNotificationCenterDelegate {
  private let channel: FlutterMethodChannel
  private let center = UNUserNotificationCenter.current()
  private let prefix = "pm.reminder."

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "progress_meter/reminders", binaryMessenger: messenger)
    super.init()
    center.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      self.handle(call, result: result)
    }
  }

  private func finish(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      center.getNotificationSettings { settings in
        self.center.getPendingNotificationRequests { pending in
          let status: String
          switch settings.authorizationStatus {
          case .authorized, .provisional: status = "authorized"
          case .denied: status = "denied"
          default: status = "notDetermined"
          }
          self.finish(result, ["authorization": status,
            "pendingCount": pending.filter { $0.identifier.hasPrefix(self.prefix) }.count])
        }
      }
    case "requestPermission":
      center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if error != nil {
          self.finish(result, FlutterError(code: "permission_unavailable", message: "macOS could not request notification permission.", details: nil))
        } else { self.finish(result, granted) }
      }
    case "replacePlan":
      guard let args = call.arguments as? [String: Any],
            let rows = args["reminders"] as? [[String: Any]], rows.count <= 64 else {
        finish(result, FlutterError(code: "invalid_plan", message: "The reminder schedule is invalid.", details: nil)); return
      }
      var requests: [UNNotificationRequest] = []
      var identifiers = Set<String>()
      for row in rows {
        guard let id = row["id"] as? String, id.hasPrefix(prefix), id.count <= 1024,
              identifiers.insert(id).inserted,
              let title = row["title"] as? String, !title.isEmpty, title.count <= 200,
              let body = row["body"] as? String, body.count <= 1000,
              let hour = row["hour"] as? Int, (0...23).contains(hour),
              let minute = row["minute"] as? Int, (0...59).contains(minute) else {
          finish(result, FlutterError(code: "invalid_plan", message: "A reminder contains invalid details.", details: nil)); return
        }
        var date = DateComponents()
        date.calendar = Calendar(identifier: .gregorian)
        date.hour = hour; date.minute = minute; date.second = 0
        let repeats: Bool
        if let weekday = row["weekday"] as? Int {
          guard (1...7).contains(weekday) else {
            finish(result, FlutterError(code: "invalid_plan", message: "Choose a valid reminder weekday.", details: nil)); return
          }
          // Dart uses Monday=1; Foundation uses Sunday=1.
          date.weekday = weekday % 7 + 1
          repeats = true
        } else {
          guard let year = row["year"] as? Int, (1...9999).contains(year),
                let month = row["month"] as? Int, (1...12).contains(month),
                let day = row["day"] as? Int, (1...31).contains(day) else {
            finish(result, FlutterError(code: "invalid_plan", message: "Choose a valid reminder date.", details: nil)); return
          }
          date.year = year; date.month = month; date.day = day
          repeats = false
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: repeats)
        guard trigger.nextTriggerDate() != nil else {
          finish(result, FlutterError(code: "invalid_plan", message: "A reminder date could not be scheduled.", details: nil)); return
        }
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        content.userInfo = ["route": "routines"]
        requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
      }
      center.getPendingNotificationRequests { pending in
        let removed = pending.filter { $0.identifier.hasPrefix(self.prefix) && !identifiers.contains($0.identifier) }.map { $0.identifier }
        self.center.removePendingNotificationRequests(withIdentifiers: removed)
        let group = DispatchGroup()
        let lock = NSLock()
        var failed = false
        for request in requests {
          group.enter()
          self.center.add(request) { error in
            if error != nil { lock.lock(); failed = true; lock.unlock() }
            group.leave()
          }
        }
        group.notify(queue: .main) {
          if failed {
            result(FlutterError(code: "schedule_failed", message: "macOS could not schedule every reminder. Refresh to try again.", details: nil))
          } else { result(requests.count) }
        }
      }
    case "sendTest":
      center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
          self.finish(result, FlutterError(code: "permission_denied", message: "Enable notifications first.", details: nil)); return
        }
        let content = UNMutableNotificationContent()
        content.title = "Progress Meter reminders"
        content.body = "Your timed reminders are ready. This is a test notification."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "pm.test-notification", content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        self.center.add(request) { error in
          self.finish(result, error == nil ? nil : FlutterError(code: "schedule_failed", message: "The test reminder could not be scheduled.", details: nil))
        }
      }
    case "openSettings":
      let bundle = Bundle.main.bundleIdentifier ?? "com.progressmeter.progressMeter"
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundle)"), NSWorkspace.shared.open(url) {
        result(nil)
      } else { result(FlutterError(code: "settings_unavailable", message: "Open System Settings, Notifications, Progress Meter.", details: nil)) }
    default: result(FlutterMethodNotImplemented)
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    completionHandler()
  }
}

// BEGIN LOCAL DOCUMENT READER
// These helpers contain no Flutter dependency so the same extraction can be
// exercised by a small command-line harness without changing user app data.
private struct DocumentReadFailure: Error {
  let code: String
  let message: String
}

private enum LocalDocumentReader {
  static let queue = DispatchQueue(label: "com.progressmeter.document-reader", qos: .userInitiated)
  static let maximumBytes = 20 * 1024 * 1024
  static let maximumPages = 12
  static let maximumTokens = 50_000
  static let words = try! NSRegularExpression(pattern: "\\S+")

  static func read(_ data: Data, name: String) throws -> [String: Any] {
    guard !data.isEmpty else {
      throw DocumentReadFailure(code: "empty_document", message: "This file is empty. Choose another document.")
    }
    guard data.count <= maximumBytes else {
      throw DocumentReadFailure(code: "document_too_large", message: "Choose a document smaller than 20 MB.")
    }
    let fileExtension = (name as NSString).pathExtension.lowercased()
    let pdfSignature = data.prefix(4) == Data("%PDF".utf8)
    if fileExtension == "pdf" || pdfSignature {
      return try readPDF(data)
    }
    guard ["png", "jpg", "jpeg", "heic", "heif", "webp", "tif", "tiff", "bmp"].contains(fileExtension) else {
      throw DocumentReadFailure(code: "unsupported_document", message: "Choose a PDF, PNG, JPEG, HEIC, WebP, TIFF, or BMP image.")
    }
    return try readImages(data)
  }

  private static func pageSize(_ page: PDFPage) -> CGSize {
    let bounds = page.bounds(for: .cropBox)
    let angle = ((page.rotation % 360) + 360) % 360
    return angle == 90 || angle == 270
      ? CGSize(width: bounds.height, height: bounds.width)
      : bounds.size
  }

  private static func readPDF(_ data: Data) throws -> [String: Any] {
    guard let document = PDFDocument(data: data) else {
      throw DocumentReadFailure(code: "invalid_pdf", message: "This PDF is damaged or is not a supported PDF document.")
    }
    guard !document.isLocked else {
      throw DocumentReadFailure(code: "locked_pdf", message: "This PDF is password protected. Export an unlocked copy and import that copy.")
    }
    guard document.pageCount > 0 && document.pageCount <= maximumPages else {
      throw DocumentReadFailure(code: "pdf_page_limit", message: "Import a PDF containing between 1 and 12 pages. Split longer documents first.")
    }
    var pages: [[String: Any]] = []
    var warnings: [String] = []
    var usedOCR = false
    var tokenCount = 0
    for index in 0..<document.pageCount {
      let output: ([String: Any], Bool, [String]) = try autoreleasepool {
        guard let page = document.page(at: index) else {
          throw DocumentReadFailure(code: "invalid_pdf", message: "A page in this PDF could not be read.")
        }
        let size = pageSize(page)
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              size.width <= 20_000, size.height <= 20_000 else {
          throw DocumentReadFailure(code: "invalid_pdf", message: "This PDF has unsupported page dimensions.")
        }
        guard page.numberOfCharacters <= 500_000 else {
          throw DocumentReadFailure(code: "document_too_complex", message: "This PDF contains too much text. Import a smaller selection of pages.")
        }
        let searchable = pdfTokens(page, displaySize: size)
        let usefulCharacters = searchable.reduce(0) { total, token in
          total + ((token["text"] as? String)?.filter { $0.isLetter || $0.isNumber }.count ?? 0)
        }
        if searchable.count >= 4 && usefulCharacters >= 16 {
          return (["width": Double(size.width), "height": Double(size.height), "tokens": searchable], false, [])
        }
        guard let image = renderPDF(page, displaySize: size) else {
          throw DocumentReadFailure(code: "pdf_render_failed", message: "A scanned PDF page could not be prepared for local text recognition.")
        }
        let recognized = try recognize(image)
        var notes = recognized.warnings
        if recognized.tokens.isEmpty { notes.append("Page \(index + 1) has no readable text.") }
        return (["width": Double(size.width), "height": Double(size.height), "tokens": recognized.tokens], true, notes)
      }
      tokenCount += (output.0["tokens"] as? [[String: Any]])?.count ?? 0
      guard tokenCount <= maximumTokens else {
        throw DocumentReadFailure(code: "document_too_complex", message: "This document contains too much text. Import fewer pages at a time.")
      }
      pages.append(output.0)
      usedOCR = usedOCR || output.1
      warnings.append(contentsOf: output.2)
    }
    return ["pages": pages, "usedOcr": usedOCR, "warnings": Array(Set(warnings)).sorted()]
  }

  private static func pdfTokens(_ page: PDFPage, displaySize: CGSize) -> [[String: Any]] {
    guard let text = page.string, let reference = page.pageRef else { return [] }
    let full = NSRange(text.startIndex..<text.endIndex, in: text)
    let target = CGRect(origin: .zero, size: displaySize)
    let transform = reference.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true)
    var tokens: [[String: Any]] = []
    for match in words.matches(in: text, range: full) {
      guard let range = Range(match.range, in: text),
            let selection = page.selection(for: match.range) else { continue }
      let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
      if value.isEmpty { continue }
      let box = selection.bounds(for: page).applying(transform).intersection(target)
      guard !box.isNull, !box.isEmpty else { continue }
      if let token = normalizedToken(value, box: box, size: displaySize) { tokens.append(token) }
      if tokens.count > maximumTokens { break }
    }
    return readingOrder(tokens)
  }

  private static func normalizedToken(_ text: String, box: CGRect, size: CGSize) -> [String: Any]? {
    guard box.minX.isFinite, box.minY.isFinite, box.width.isFinite, box.height.isFinite,
          size.width > 0, size.height > 0 else { return nil }
    let x = max(0, min(1, box.minX / size.width))
    let y = max(0, min(1, 1 - box.maxY / size.height))
    let width = max(0, min(1 - x, box.width / size.width))
    let height = max(0, min(1 - y, box.height / size.height))
    guard width > 0, height > 0 else { return nil }
    return ["text": text, "x": Double(x), "y": Double(y), "width": Double(width), "height": Double(height)]
  }

  private static func readingOrder(_ tokens: [[String: Any]]) -> [[String: Any]] {
    tokens.sorted { a, b in
      let ay = a["y"] as? Double ?? 0
      let by = b["y"] as? Double ?? 0
      if abs(ay - by) > 0.002 { return ay < by }
      return (a["x"] as? Double ?? 0) < (b["x"] as? Double ?? 0)
    }
  }

  private static func renderPDF(_ page: PDFPage, displaySize: CGSize) -> CGImage? {
    guard let reference = page.pageRef else { return nil }
    let factor = 2200.0 / max(displaySize.width, displaySize.height)
    let width = max(1, Int((displaySize.width * factor).rounded()))
    let height = max(1, Int((displaySize.height * factor).rounded()))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let target = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(NSColor.white.cgColor)
    context.fill(target)
    context.concatenate(reference.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
    context.drawPDFPage(reference)
    return context.makeImage()
  }

  private static func readImages(_ data: Data) throws -> [String: Any] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw DocumentReadFailure(code: "invalid_image", message: "This image is damaged or its format is not supported on this Mac.")
    }
    let count = CGImageSourceGetCount(source)
    guard count > 0 && count <= maximumPages else {
      throw DocumentReadFailure(code: "image_page_limit", message: "Import an image document with at most 12 frames or pages.")
    }
    var totalPixels = 0.0
    var totalTokens = 0
    var pages: [[String: Any]] = []
    var warnings: [String] = []
    for index in 0..<count {
      let page: ([String: Any], [String]) = try autoreleasepool {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let imageWidth = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let imageHeight = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
          throw DocumentReadFailure(code: "invalid_image", message: "The image dimensions could not be read.")
        }
        let pixels = imageWidth.doubleValue * imageHeight.doubleValue
        totalPixels += pixels
        guard pixels.isFinite, pixels > 0, pixels <= 100_000_000, totalPixels <= 200_000_000 else {
          throw DocumentReadFailure(code: "image_too_large", message: "Use an image smaller than 100 megapixels, or fewer image pages.")
        }
        let options: [CFString: Any] = [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 3000,
          kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
          throw DocumentReadFailure(code: "invalid_image", message: "This image could not be prepared for local text recognition.")
        }
        let recognized = try recognize(image)
        var notes = recognized.warnings
        if recognized.tokens.isEmpty { notes.append("Image page \(index + 1) has no readable text.") }
        return (["width": image.width, "height": image.height, "tokens": recognized.tokens], notes)
      }
      totalTokens += (page.0["tokens"] as? [[String: Any]])?.count ?? 0
      guard totalTokens <= maximumTokens else {
        throw DocumentReadFailure(code: "document_too_complex", message: "This image contains too much text. Import a smaller selection.")
      }
      pages.append(page.0)
      warnings.append(contentsOf: page.1)
    }
    return ["pages": pages, "usedOcr": true, "warnings": Array(Set(warnings)).sorted()]
  }

  private static func recognize(_ image: CGImage) throws -> (tokens: [[String: Any]], warnings: [String]) {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]
    request.minimumTextHeight = 0.003
    let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
    do { try handler.perform([request]) }
    catch {
      throw DocumentReadFailure(code: "ocr_unavailable", message: "Local text recognition could not finish. Try a sharper image or a searchable PDF.")
    }
    var tokens: [[String: Any]] = []
    var warnings: [String] = []
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first else { continue }
      let text = candidate.string
      let full = NSRange(text.startIndex..<text.endIndex, in: text)
      for match in words.matches(in: text, range: full) {
        guard let range = Range(match.range, in: text) else { continue }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { continue }
        let exact = try? candidate.boundingBox(for: range)
        let rectangle = exact?.boundingBox ?? observation.boundingBox
        if exact == nil { warnings.append("Some OCR words use a full-line position. Review extracted columns carefully.") }
        if let token = normalizedToken(value, box: rectangle, size: CGSize(width: 1, height: 1)) {
          tokens.append(token)
        }
        if tokens.count > maximumTokens {
          throw DocumentReadFailure(code: "document_too_complex", message: "This image contains too much text. Import a smaller selection.")
        }
      }
    }
    return (readingOrder(tokens), warnings)
  }
}
