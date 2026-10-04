// Removes the alpha channel from a screenshot, keeping its exact pixel size.
//
// App Store Connect rejects any screenshot carrying an alpha channel, and the
// error it shows for it talks about dimensions, which sends you looking in the
// wrong place. simctl screenshots are always RGBA even though every pixel is
// fully opaque, so every image capture.sh produced had to be flattened.
//
// usage: swift flatten.swift <file.png>   (rewrites in place)
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else { print("usage: flatten.swift <file.png>"); exit(2) }
let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)
guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("could not read \(path)"); exit(1)
}
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: img.width, height: img.height,
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
ctx.setFillColor(CGColor(colorSpace: cs, components: [0, 0, 0, 1])!)
ctx.fill(CGRect(x: 0, y: 0, width: img.width, height: img.height))
ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
