import AppKit

extension NSImage {
    /// Returns a square-cropped, resized copy of this image at the given pixel dimension.
    func iconResized(to dimension: Int) -> NSImage {
        let targetSize = NSSize(width: dimension, height: dimension)
        let result = NSImage(size: targetSize)
        result.lockFocus()
        defer { result.unlockFocus() }

        guard let ctx = NSGraphicsContext.current else { return result }
        ctx.imageInterpolation = .high

        let src = self.size
        // Centre-crop: scale so the shorter side fills the square.
        let scale = max(CGFloat(dimension) / src.width, CGFloat(dimension) / src.height)
        let scaledW = src.width  * scale
        let scaledH = src.height * scale
        let destX = (CGFloat(dimension) - scaledW) / 2
        let destY = (CGFloat(dimension) - scaledH) / 2

        draw(in:   NSRect(x: destX, y: destY, width: scaledW, height: scaledH),
             from: NSRect(origin: .zero, size: src),
             operation: .copy,
             fraction: 1.0)
        return result
    }

    /// Encodes the image as PNG data.
    func pngData() -> Data? {
        guard let tiff   = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
