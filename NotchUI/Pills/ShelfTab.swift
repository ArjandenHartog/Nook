import SwiftUI
import UniformTypeIdentifiers

/// Shelf: sleep bestanden hierheen om ze even te bewaren. Nu nog alleen in het geheugen.
struct ShelfTab: View {
    @State private var files: [URL] = []
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(files, id: \.self) { url in
                VStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 36, height: 36)
                    Text(url.lastPathComponent)
                        .font(NookTheme.font(12))
                        .foregroundStyle(NookTheme.paper)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 8)
                .frame(width: 108, height: 104)
                .background(RoundedRectangle(cornerRadius: 14).fill(NookTheme.field))
            }

            VStack(spacing: 4) {
                Text("Sleep bestanden hierheen")
                    .font(NookTheme.font(12.5, .medium))
                    .foregroundStyle(NookTheme.paper)
                Text("bewaren, AirDrop of vraag Nook erover")
                    .font(NookTheme.font(12.5))
                    .foregroundStyle(NookTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        targeted ? NookTheme.iris : NookTheme.line2,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        if !files.contains(url) { files.append(url) }
                    }
                }
            }
            return true
        }
    }
}
