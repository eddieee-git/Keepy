// Keepy 앱 아이콘을 그려 Resources/AppIcon.icns와 docs/images/icon.png를 만든다.
// 실행: swift scripts/make-icon.swift
import AppKit

func draw(in size: CGFloat) {
    let scale = size / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)

    // 배경: macOS 아이콘 격자에 맞춘 둥근 사각형
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.78, blue: 0.70, alpha: 1),
               ending: NSColor(srgbRed: 0.18, green: 0.42, blue: 0.92, alpha: 1))!.draw(in: tile, angle: -60)

    let shadow = NSColor.black.withAlphaComponent(0.28).cgColor

    // 뒤에 쌓인 기록: 살짝 기울어진 반투명 카드
    context.saveGState()
    context.translateBy(x: 560, y: 470)
    context.rotate(by: 8 * .pi / 180)
    NSColor.white.withAlphaComponent(0.45).setFill()
    NSBezierPath(roundedRect: NSRect(x: -200, y: -250, width: 400, height: 500), xRadius: 40, yRadius: 40).fill()
    context.restoreGState()

    // 클립보드 판
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24 * scale), blur: 50 * scale, color: shadow)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 282, y: 200, width: 420, height: 560), xRadius: 44, yRadius: 44).fill()
    context.restoreGState()

    // 집게
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 20 * scale, color: shadow)
    NSColor(srgbRed: 0.13, green: 0.25, blue: 0.45, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 400, y: 705, width: 184, height: 100), xRadius: 30, yRadius: 30).fill()
    context.restoreGState()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 472, y: 760, width: 40, height: 28)).fill()

    // 글 줄
    let lineColor = NSColor(srgbRed: 0.18, green: 0.50, blue: 0.86, alpha: 1)
    for (index, width) in [300.0, 240, 280, 180].enumerated() {
        let y = 600 - CGFloat(index) * 92
        let color = index == 0 ? lineColor : lineColor.withAlphaComponent(0.35)
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 342, y: y, width: width, height: 38), xRadius: 19, yRadius: 19).fill()
    }
}

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(in: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("KeepyIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()

// README 머리에 쓰는 아이콘
try FileManager.default.createDirectory(atPath: "docs/images", withIntermediateDirectories: true)
try png(256).write(to: URL(fileURLWithPath: "docs/images/icon.png"))
