import SwiftUI
import UniformTypeIdentifiers

/// Sheet opened from "Share" in the snooze sheet: previews the share image and offers the share sheet.
///
/// Two styles: the full card (bobble, graph, IOB/COB/eventual, times), or the bobble alone on a
/// transparent background for laying over a photo in a social post.
struct ShareCardSheet: View {
    enum Style: Hashable {
        case card
        case bobble
    }

    let snapshot: ShareCardSnapshot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var style: Style = .card
    @State private var cardImage: UIImage?
    @State private var bobbleImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Style", selection: $style) {
                    Text("Card").tag(Style.card)
                    Text("Bobble").tag(Style.bobble)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                GeometryReader { geo in
                    preview(in: geo.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.top, 8)
            .navigationTitle(Text("Share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    shareButton
                }
            }
        }
        .onAppear(perform: renderImages)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Preview

    @ViewBuilder private func preview(in available: CGSize) -> some View {
        switch style {
        case .card:
            let size = ShareCardView.size
            let fit = min(1, (available.width - 32) / size.width, (available.height - 24) / size.height)
            ShareCardView(snapshot: snapshot)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(fit)
                .frame(width: size.width * fit, height: size.height * fit)
        case .bobble:
            let side = ShareBobbleView.overlaySide
            let fit = min(1, (available.width - 32) / side, (available.height - 24) / side)
            // Shown over the sheet's own background; the shared PNG is transparent outside the ring.
            ShareBobbleView(snapshot: snapshot, side: side)
                .scaleEffect(fit)
                .frame(width: side * fit, height: side * fit)
        }
    }

    // MARK: - Sharing

    private var currentImage: UIImage? {
        switch style {
        case .card: return cardImage
        case .bobble: return bobbleImage
        }
    }

    @ViewBuilder private var shareButton: some View {
        if let image = currentImage, let png = image.pngData() {
            ShareLink(
                item: SharedPNG(data: png),
                preview: SharePreview("Share", image: Image(uiImage: image))
            ) {
                Image(systemName: "square.and.arrow.up")
            }
        } else {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.secondary)
        }
    }

    /// Renders both styles once at the screen's scale: the card at 1080 × 1350 px and the bobble at
    /// 1080 × 1080 px on a 3x device. The bobble keeps a transparent background.
    private func renderImages() {
        if cardImage == nil {
            let renderer = ImageRenderer(content: ShareCardView(snapshot: snapshot))
            renderer.scale = displayScale
            renderer.isOpaque = true
            cardImage = renderer.uiImage
        }
        if bobbleImage == nil {
            let renderer = ImageRenderer(
                content: ShareBobbleView(snapshot: snapshot, side: ShareBobbleView.overlaySide)
            )
            renderer.scale = displayScale
            renderer.isOpaque = false
            bobbleImage = renderer.uiImage
        }
    }
}

/// PNG export for the share sheet. PNG (rather than letting `Image` pick a format) keeps the bobble's
/// transparency, so it can be laid over a photo.
private struct SharedPNG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.data
        }
        .suggestedFileName("Trio.png")
    }
}
