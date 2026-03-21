#!/usr/bin/swift
import AppKit

let iconsetPath = "/Users/doyoungkwak/Desktop/CaffeineToggle-src/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

for (size, name) in sizes {
    let s = CGFloat(size)

    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { continue }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep) else { continue }
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // 투명 배경 초기화
    cg.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Apple 스타일 Squircle 클리핑
    let r = s * 0.225
    let squircle = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                          cornerWidth: r, cornerHeight: r, transform: nil)
    cg.addPath(squircle)
    cg.clip()

    // 배경 그라디언트 (따뜻한 커피색: 짙은 갈색 → 황금빛 앰버)
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.75, green: 0.38, blue: 0.06, alpha: 1.0), // amber
        CGColor(red: 0.22, green: 0.08, blue: 0.01, alpha: 1.0), // deep brown
    ] as CFArray
    guard let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0]) else { continue }
    cg.drawLinearGradient(gradient,
                          start: CGPoint(x: 0, y: s),
                          end:   CGPoint(x: s, y: 0),
                          options: [])

    // 흰색 커피컵 SF Symbol
    let pt = s * 0.50
    if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: pt, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let img = symbol.withSymbolConfiguration(config) {
            let iw = img.size.width, ih = img.size.height
            img.draw(in: NSRect(x: (s - iw) / 2, y: (s - ih) / 2, width: iw, height: ih),
                     from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    NSGraphicsContext.restoreGraphicsState()

    if let png = bitmapRep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
        print("✓ \(name).png (\(size)px)")
    }
}
print("아이콘 생성 완료!")
