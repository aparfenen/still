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
    let bookmark = NSBezierPath()
    bookmark.move(to: NSPoint(x: 332, y: 752))
    bookmark.line(to: NSPoint(x: 692, y: 752))
    bookmark.line(to: NSPoint(x: 692, y: 272))
    bookmark.line(to: NSPoint(x: 512, y: 432))
    bookmark.line(to: NSPoint(x: 332, y: 272))
    bookmark.close()
    NSColor(red: 0.69, green: 0.59, blue: 0.86, alpha: 1).setFill()
    bookmark.fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon.") }
    try png.write(to: path)
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(pixels: size, path: destination.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(pixels: size * 2, path: destination.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
