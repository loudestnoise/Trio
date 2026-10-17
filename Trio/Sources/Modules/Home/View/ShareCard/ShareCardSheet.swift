import SwiftUI

/// Sheet opened by long-pressing the glucose bobble: previews the share card and offers the share sheet.
struct ShareCardSheet: View {
    let snapshot: ShareCardSnapshot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var renderedImage: Image?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let fit = min(
                    1,
                    (geo.size.width - 32) / ShareCardView.size.width,
                    (geo.size.height - 24) / ShareCardView.size.height
                )
                ShareCardView(snapshot: snapshot)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .scaleEffect(fit)
                    .frame(width: ShareCardView.size.width * fit, height: ShareCardView.size.height * fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(Text("Share Card"))
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
        .onAppear(perform: renderImage)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var shareButton: some View {
        if let renderedImage {
            ShareLink(
                item: renderedImage,
                preview: SharePreview("Glucose card", image: renderedImage)
            ) {
                Image(systemName: "square.and.arrow.up")
            }
        } else {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.secondary)
        }
    }

    /// Renders the card once at the screen's scale (1080 × 1350 px on a 3x device).
    private func renderImage() {
        guard renderedImage == nil else { return }
        let renderer = ImageRenderer(content: ShareCardView(snapshot: snapshot))
        renderer.scale = displayScale
        renderer.isOpaque = true
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}
