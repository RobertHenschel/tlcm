import SwiftUI
import AppKit

struct ConnectionIconView: View {
    let iconURL: URL
    @Binding var loadedIcon: NSImage?

    var body: some View {
        Group {
            if let icon = loadedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
            }
        }
        .onAppear { reload() }
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: iconURL.path),
              let img = NSImage(contentsOf: iconURL) else {
            loadedIcon = nil
            return
        }
        loadedIcon = img
    }
}

/// Resize + save a source image to the given destination URL; returns the resized image on success.
func saveConnectionIcon(from sourceURL: URL, to destURL: URL) -> NSImage? {
    guard let source = NSImage(contentsOf: sourceURL) else { return nil }
    let resized = source.iconResized(to: 128)
    guard let data = resized.pngData() else { return nil }
    do {
        try data.write(to: destURL, options: .atomic)
        return resized
    } catch {
        return nil
    }
}
