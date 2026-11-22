import Cocoa
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let bg = NSBezierPath(roundedRect: rect, xRadius: 186, yRadius: 186)
// 投影
ctx.saveGState()
let sh = NSShadow(); sh.shadowBlurRadius = 28; sh.shadowOffset = NSSize(width: 0, height: -10)
sh.shadowColor = NSColor.black.withAlphaComponent(0.28); sh.set()
NSColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1).setFill(); bg.fill()
ctx.restoreGState()

ctx.saveGState(); bg.addClip()
// 纸张：极轻的上下明暗
NSGradient(colors: [NSColor(red: 0.985, green: 0.975, blue: 0.955, alpha: 1),
                    NSColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 1)])!.draw(in: rect, angle: -90)

// 大号宋体“字”
let ink = NSColor(red: 0.11, green: 0.10, blue: 0.10, alpha: 1)
let font = NSFont(name: "STSongti-SC-Black", size: 600) ?? NSFont(name: "Songti SC", size: 600)!
let str = NSAttributedString(string: "字", attributes: [.font: font, .foregroundColor: ink])
let sz = str.size()
str.draw(at: NSPoint(x: (S - sz.width) / 2, y: (S - sz.height) / 2 - 30))

// 朱红选框：半透明填充 + 细线 + 四角手柄
let red = NSColor(red: 0.86, green: 0.22, blue: 0.15, alpha: 1)
let sel = NSRect(x: 236, y: 236, width: 552, height: 330)
red.withAlphaComponent(0.10).setFill(); NSBezierPath(rect: sel).fill()
let border = NSBezierPath(rect: sel); border.lineWidth = 7
red.setStroke(); border.stroke()
for p in [NSPoint(x: sel.minX, y: sel.minY), NSPoint(x: sel.maxX, y: sel.minY),
          NSPoint(x: sel.minX, y: sel.maxY), NSPoint(x: sel.maxX, y: sel.maxY)] {
    let h = NSRect(x: p.x - 19, y: p.y - 19, width: 38, height: 38)
    NSColor.white.setFill(); NSBezierPath(rect: h).fill()
    let hb = NSBezierPath(rect: h); hb.lineWidth = 7; red.setStroke(); hb.stroke()
}
ctx.restoreGState()
// 细描边
let edge = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 185, yRadius: 185)
edge.lineWidth = 2; NSColor.black.withAlphaComponent(0.08).setStroke(); edge.stroke()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
