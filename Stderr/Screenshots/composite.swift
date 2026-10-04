// Composites a hand-captured window onto an opaque Mac App Store canvas.
//
// Written as a drawing step rather than a chain of sips calls because a window
// captured with Shift-Cmd-4-Space carries a transparent drop shadow, and
// padding a transparent PNG leaves the shadow punched through to nothing.
// Drawing onto an opaque canvas flattens it properly.
//
// usage: swift composite.swift <in.png> <out.png> <width> <height> <RRGGBB>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count == 6, let w = Int(a[3]), let h = Int(a[4]) else {
    print("usage: swift composite.swift <in.png> <out.png> <width> <height> <RRGGBB>")
    exit(2)
}
let inPath = a[1], outPath = a[2]
let hex = UInt32(a[5], radix: 16) ?? 0

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("could not read \(inPath)"); exit(1)
}

// THE GUARD. Job Trail shipped a 248x238 capture scaled up to 1440x900; every
// word in it is illegible. Upscaling a window capture never produces a usable
// store image, so refuse rather than quietly blur it.
let scale = min(Double(w) * 0.88 / Double(img.width), Double(h) * 0.88 / Double(img.height))
if scale > 1.0 {
    print("REFUSED \(inPath): \(img.width)x\(img.height) is too small for \(w)x\(h) — "
        + "it would have to be upscaled \(String(format: "%.1f", scale))x and would ship blurry. "
        + "Re-capture this window larger.")
    exit(3)
}

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
ctx.setFillColor(CGColor(colorSpace: cs, components: [
    CGFloat((hex >> 16) & 0xFF)/255, CGFloat((hex >> 8) & 0xFF)/255, CGFloat(hex & 0xFF)/255, 1])!)
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

let dw = Double(img.width) * scale, dh = Double(img.height) * scale
ctx.interpolationQuality = .high
ctx.draw(img, in: CGRect(x: (Double(w) - dw)/2, y: (Double(h) - dh)/2, width: dw, height: dh))

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("  \(outPath)  \(w)x\(h)")
