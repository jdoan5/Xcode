// flatten.swift - removes the alpha channel from App Store screenshots.
//
// Usage: swift flatten.swift <file.png> [more.png ...]     (each file is rewritten in place)
//
// Why this exists: simulator screenshots are RGBA PNGs. App Store Connect rejects any
// screenshot with an alpha channel, and the error it shows talks about the image size, not
// the alpha, which sends you looking in the wrong place. `sips --setProperty hasAlpha false`
// only edits a metadata flag and leaves the channel in the file, so the image is redrawn
// here into an opaque bitmap (no alpha byte at all) and written out again.
//
// Pixels are composited over white first, so any transparent pixel becomes white rather
// than black. Simulator screenshots are fully opaque in practice; this is a safety net.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FlattenError: Error, CustomStringConvertible {
    case unreadable(String)
    case noContext(String)
    case notWritten(String)

    var description: String {
        switch self {
        case .unreadable(let path): "cannot read an image from \(path)"
        case .noContext(let path): "cannot make an opaque bitmap for \(path)"
        case .notWritten(let path): "cannot write \(path)"
        }
    }
}

/// Redraws one PNG into an opaque sRGB bitmap of the same pixel size and replaces the file.
func flatten(_ path: String) throws {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw FlattenError.unreadable(path)
    }
    let width = image.width
    let height = image.height
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    // noneSkipLast: 8 bits each of R, G, B and one ignored byte. The written PNG is RGB.
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: sRGB,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw FlattenError.noContext(path)
    }
    let frame = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fill(frame)
    context.draw(image, in: frame)
    guard let opaque = context.makeImage() else { throw FlattenError.noContext(path) }

    // Written to a sibling file and moved over the original, so a failure never leaves a
    // half-written screenshot behind.
    let temporary = url.deletingLastPathComponent()
        .appendingPathComponent(".flatten-\(UUID().uuidString).png")
    guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, UTType.png.identifier as CFString,
                                                            1, nil) else {
        throw FlattenError.notWritten(path)
    }
    CGImageDestinationAddImage(destination, opaque, nil)
    guard CGImageDestinationFinalize(destination) else {
        try? FileManager.default.removeItem(at: temporary)
        throw FlattenError.notWritten(path)
    }
    _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)

    print("flattened \(url.lastPathComponent): \(width)x\(height), alpha removed")
}

let paths = Array(CommandLine.arguments.dropFirst())
if paths.isEmpty {
    FileHandle.standardError.write(Data("usage: swift flatten.swift <file.png> [more.png ...]\n".utf8))
    exit(2)
}
var failed = false
for path in paths {
    do {
        try flatten(path)
    } catch {
        FileHandle.standardError.write(Data("flatten: \(error)\n".utf8))
        failed = true
    }
}
exit(failed ? 1 : 0)
