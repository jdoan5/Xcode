// frames.swift - two checks on raw simulator captures, used by capture.sh.
//
// Usage:
//   frames blank <file.png>              exit 1 when the frame is one colour (the app had not drawn yet)
//   frames corner <file.png> [more ...]  paint over the simulator's corner mark, in place
//
// blank: a launch that is still on the generated launch screen captures as plain white with
// only the status bar on it, and capture.sh would otherwise copy it into UPLOAD/ as if it were
// a screen. A frame where one colour covers 90% or more of the pixels is reported as blank;
// Stand Study's real screens stay well under half (paper, card, gray mat and the artwork).
//
// corner: the iOS 27 iPhone simulators (18 Pro Max and Duo) draw a 3x3-pixel black square,
// with a one-pixel soft edge, in the top-left corner of every capture. It is not part of the
// app. When those nine pixels are pure black, the 4x4 corner is filled with the colour just
// beside it (pixel 5,5), which is the screen's own background there. Any other file is left
// exactly as it is. Nothing else in the image changes, and the alpha channel is kept
// (flatten.swift removes it later, from the marketing copies only).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Bitmap {
    let image: CGImage
    let context: CGContext
    let width: Int
    let height: Int
    let pixels: UnsafeMutablePointer<UInt8>

    init?(path: String) {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        self.image = image
        self.context = context
        width = image.width
        height = image.height
        pixels = data.assumingMemoryBound(to: UInt8.self)
    }

    /// Row 0 is the top of the picture in a bitmap context's memory.
    func offset(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }

    /// The share of all pixels taken by the most common colour.
    var dominantShare: Double {
        var counts: [UInt32: Int] = [:]
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let key = UInt32(pixels[i]) << 16 | UInt32(pixels[i + 1]) << 8 | UInt32(pixels[i + 2])
            counts[key, default: 0] += 1
        }
        return Double(counts.values.max() ?? 0) / Double(width * height)
    }

    func write(to path: String) -> Bool {
        guard let output = context.makeImage() else { return false }
        let url = URL(fileURLWithPath: path)
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".frames-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL,
                                                                UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination),
              (try? FileManager.default.replaceItemAt(url, withItemAt: temporary)) != nil else {
            try? FileManager.default.removeItem(at: temporary)
            return false
        }
        return true
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("frames: \(message)\n".utf8))
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first, arguments.count >= 2 else {
    fail("usage: frames blank <file.png> | frames corner <file.png> [more.png ...]")
}

switch command {
case "blank":
    guard let bitmap = Bitmap(path: arguments[1]) else { fail("cannot read \(arguments[1])") }
    let share = bitmap.dominantShare
    print(String(format: "one colour covers %.0f%%", share * 100))
    exit(share >= 0.9 ? 1 : 0)

case "corner":
    for path in arguments.dropFirst() {
        guard let bitmap = Bitmap(path: path) else { fail("cannot read \(path)") }
        guard bitmap.width > 8, bitmap.height > 8 else { continue }
        let p = bitmap.pixels
        let marked = (0..<3).allSatisfy { y in
            (0..<3).allSatisfy { x in
                let i = bitmap.offset(x, y)
                return p[i] == 0 && p[i + 1] == 0 && p[i + 2] == 0
            }
        }
        let fill = bitmap.offset(5, 5)
        let fillIsBlack = p[fill] == 0 && p[fill + 1] == 0 && p[fill + 2] == 0
        guard marked, !fillIsBlack else {
            print("\(URL(fileURLWithPath: path).lastPathComponent): no corner mark, unchanged")
            continue
        }
        for y in 0..<4 {
            for x in 0..<4 {
                let i = bitmap.offset(x, y)
                for c in 0..<4 { p[i + c] = p[fill + c] }
            }
        }
        guard bitmap.write(to: path) else { fail("cannot write \(path)") }
        print("\(URL(fileURLWithPath: path).lastPathComponent): corner mark painted over")
    }

default:
    fail("unknown command \(command)")
}
