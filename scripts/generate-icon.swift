import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { fatalError("Supply the destination .iconset directory.") }
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func drawIcon(pixels: Int, path: URL) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render icon.") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    NSColor(red: 0.965, green: 0.953, blue: 0.985, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944),
                 xRadius: 210, yRadius: 210).fill()
    let flag = NSBezierPath()
    flag.move(to: NSPoint(x: 354, y: 730))
    flag.curve(to: NSPoint(x: 712, y: 704), controlPoint1: NSPoint(x: 478, y: 810),
               controlPoint2: NSPoint(x: 584, y: 638))
    flag.line(to: NSPoint(x: 712, y: 474))
    flag.curve(to: NSPoint(x: 354, y: 500), controlPoint1: NSPoint(x: 584, y: 408),
               controlPoint2: NSPoint(x: 478, y: 580))
    flag.close()
    NSColor(red: 0.69, green: 0.59, blue: 0.86, alpha: 1).setFill()
    flag.fill()
    NSColor(red: 0.24, green: 0.21, blue: 0.30, alpha: 1).setStroke()
    flag.lineWidth = 18
    flag.lineJoinStyle = .round
    flag.stroke()
    let pole = NSBezierPath()
    pole.move(to: NSPoint(x: 354, y: 748))
    pole.line(to: NSPoint(x: 354, y: 282))
    pole.lineWidth = 26
    pole.lineCapStyle = .round
    pole.stroke()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon.") }
    try png.write(to: path)
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(pixels: size, path: destination.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(pixels: size * 2, path: destination.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
