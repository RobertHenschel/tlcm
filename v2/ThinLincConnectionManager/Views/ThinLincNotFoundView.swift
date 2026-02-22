import SwiftUI
import AppKit

struct ThinLincNotFoundView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("ThinLinc Client Not Found")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This app requires the ThinLinc client to be installed.\n\nInstall it from:")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("https://www.cendio.com/thinlinc/download/", destination: URL(string: "https://www.cendio.com/thinlinc/download/")!)
                .font(.body)
            Text("Then restart ThinLinc Connection Manager.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(40)
        .frame(minWidth: 360, minHeight: 280)
    }
}

#if DEBUG
#Preview {
    ThinLincNotFoundView()
        .frame(width: 360, height: 320)
}
#endif
