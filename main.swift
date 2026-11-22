import Cocoa
import Vision
import Carbon.HIToolbox
import ServiceManagement

func dlog(_ m: String) {
    let line = "\(Date()) \(m)\n"
    let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/TextGrab.log")
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
    else { try? line.write(to: url, atomically: true, encoding: .utf8) }
}

// MARK: - 全局热键 (Carbon，无需辅助功能权限)
var hotKeyAction: (() -> Void)?

func registerHotKey(keyCode: UInt32, modifiers: UInt32) -> EventHotKeyRef? {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let st1 = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        dlog("hotkey pressed")
        DispatchQueue.main.async { hotKeyAction?() }
        return noErr
    }, 1, &spec, nil, nil)
    var ref: EventHotKeyRef?
    let id = EventHotKeyID(signature: OSType(0x54475242), id: 1) // 'TGRB'
    let st2 = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    dlog("install=\(st1) register=\(st2) screenAccess=\(CGPreflightScreenCaptureAccess())")
    return ref
}

// MARK: - 小提示浮窗
final class HUD {
    static var panel: NSPanel?
    static func show(_ text: String, symbol: String = "checkmark", tint: NSColor = .white) {
        panel?.close()
        // 深色小胶囊，类似系统音量/亮度提示
        let h: CGFloat = 34, pad: CGFloat = 14, gap: CGFloat = 6, iconSize: CGFloat = 15
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: iconSize, weight: .semibold))!)
        icon.contentTintColor = tint
        icon.sizeToFit()
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.95)
        label.sizeToFit()
        let w = pad + icon.frame.width + gap + label.frame.width + pad + 2
        let size = NSSize(width: w, height: h)
        icon.frame.origin = NSPoint(x: pad, y: (h - icon.frame.height) / 2)
        label.frame.origin = NSPoint(x: pad + icon.frame.width + gap, y: (h - label.frame.height) / 2)

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        let bg = NSView(frame: NSRect(origin: .zero, size: size))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.82).cgColor
        bg.layer?.cornerRadius = h / 2
        bg.layer?.borderWidth = 0.5
        bg.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        bg.addSubview(icon)
        bg.addSubview(label)
        p.contentView = bg

        // 出现在鼠标所在屏幕的下方中间
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let f = screen.visibleFrame
        let target = NSPoint(x: f.midX - w / 2, y: f.minY + 90)
        p.setFrameOrigin(NSPoint(x: target.x, y: target.y - 12))
        p.alphaValue = 0
        p.orderFrontRegardless()
        panel = p
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
            p.animator().setFrameOrigin(target)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            guard panel === p else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.close(); if panel === p { panel = nil }
            })
        }
    }
}

// MARK: - App
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var busy = false
    let ocrQueue = DispatchQueue(label: "textgrab.ocr", qos: .userInitiated)  // 所有识别都在同一个串行队列
    let defaults = UserDefaults.standard
    var keepLineBreaks: Bool {
        get { defaults.object(forKey: "keepLineBreaks") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "keepLineBreaks") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "TextGrab")
        buildMenu()

        // ⇧⌘2
        hotKeyAction = { [weak self] in self?.capture() }
        hotKeyRef = registerHotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey))

        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
        warmUp()
    }

    // 启动时空跑一次识别，提前加载模型，避免第一次按快捷键很慢
    func warmUp() {
        ocrQueue.async {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 80, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 400, height: 80).fill()
            NSAttributedString(string: "预热 warm up", attributes: [.font: NSFont.systemFont(ofSize: 36)]).draw(at: NSPoint(x: 10, y: 20))
            NSGraphicsContext.restoreGraphicsState()
            let start = Date()
            if let cg = rep.cgImage { _ = self.recognize(cg) }
            dlog(String(format: "warm-up done in %.2fs", Date().timeIntervalSince(start)))
        }
    }

    func buildMenu() {
        let m = NSMenu()
        let cap = NSMenuItem(title: "识别屏幕文字", action: #selector(capture), keyEquivalent: "2")
        cap.keyEquivalentModifierMask = [.command, .shift]
        m.addItem(cap)
        m.addItem(.separator())
        let lb = NSMenuItem(title: "保留换行", action: #selector(toggleLineBreaks), keyEquivalent: "")
        lb.state = keepLineBreaks ? .on : .off
        m.addItem(lb)
        let login = NSMenuItem(title: "开机启动", action: #selector(toggleLogin), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        m.addItem(login)
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "退出 TextGrab", action: #selector(NSApp.terminate), keyEquivalent: "q"))
        statusItem.menu = m
    }

    @objc func toggleLineBreaks() { keepLineBreaks.toggle(); buildMenu() }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { HUD.show("设置失败", symbol: "xmark.circle.fill", tint: .systemRed) }
        buildMenu()
    }

    @objc func capture() {
        dlog("capture called busy=\(busy)")
        guard !busy else { return }
        busy = true
        let path = NSTemporaryDirectory() + "textgrab-\(UUID().uuidString).png"
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-i", "-x", path]   // 交互式框选，无快门声
            try? p.run()
            p.waitUntilExit()
            dlog("screencapture exit=\(p.terminationStatus) fileExists=\(FileManager.default.fileExists(atPath: path))")
            defer { try? FileManager.default.removeItem(atPath: path) }
            guard let img = NSImage(contentsOfFile: path),
                  let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { self.busy = false }   // 用户按了 Esc
                return
            }
            let t0 = Date()
            let text = self.ocrQueue.sync { self.recognize(cg) }
            dlog("image \(cg.width)x\(cg.height) text chars=\(text.count) ocr=\(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
            DispatchQueue.main.async {
                self.busy = false
                if text.isEmpty { HUD.show("未识别到文字", symbol: "exclamationmark.triangle.fill", tint: .systemYellow); NSSound.beep(); return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                NSSound(named: "Tink")?.play()
                HUD.show("已复制")
            }
        }
    }

    func makeTextRequest(cpu: Bool) -> VNRecognizeTextRequest {
        let r = VNRecognizeTextRequest()
        r.recognitionLevel = .accurate
        r.usesLanguageCorrection = true
        r.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        if cpu {
            if #available(macOS 14.0, *) {
                if let devs = try? r.supportedComputeStageDevices {
                    for (stage, list) in devs {
                        if let c = list.first(where: { if case .cpu = $0 { return true } else { return false } }) {
                            r.setComputeDevice(c, for: stage)
                        }
                    }
                }
            } else {
                r.usesCPUOnly = true
            }
        }
        return r
    }

    func recognize(_ image: CGImage) -> String {
        let codeReq = VNDetectBarcodesRequest()
        var textReq = makeTextRequest(cpu: false)
        // 神经网络引擎偶尔会报 e5rtError：先重试一次，再退回 CPU
        for attempt in 0..<3 {
            if attempt == 2 { textReq = makeTextRequest(cpu: true) }
            else if attempt == 1 { textReq = makeTextRequest(cpu: false) }
            do {
                try VNImageRequestHandler(cgImage: image).perform(attempt == 0 ? [textReq, codeReq] : [textReq])
                if attempt > 0 { dlog("vision ok on attempt \(attempt)") }
                break
            } catch {
                dlog("vision error (attempt \(attempt)): \(error)")
            }
        }

        let codes = (codeReq.results ?? []).compactMap { $0.payloadStringValue }
        if !codes.isEmpty { return codes.joined(separator: "\n") }  // 二维码/条形码优先

        let lines = (textReq.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        if keepLineBreaks { return lines.joined(separator: "\n") }
        // 合并成一段：中日韩字符之间不加空格
        var out = ""
        for l in lines {
            if let a = out.last, let b = l.first, !(isCJK(a) || isCJK(b)) { out += " " }
            out += l
        }
        return out
    }

    func isCJK(_ c: Character) -> Bool {
        guard let s = c.unicodeScalars.first?.value else { return false }
        return (0x3000...0x9FFF).contains(s) || (0xAC00...0xD7AF).contains(s) || (0xFF00...0xFFEF).contains(s)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
