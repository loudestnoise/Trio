import SwiftUI
import UIKit

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
    var theme: ShareTheme = .standard

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
            .navigationTitle(Text(theme.name))
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
            ShareCardView(snapshot: snapshot, theme: theme)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(fit)
                .frame(width: size.width * fit, height: size.height * fit)
        case .bobble:
            let side = ShareBobbleView.overlaySide
            let fit = min(1, (available.width - 32) / side, (available.height - 24) / side)
            // Shown over the sheet's own background; the shared PNG is transparent outside the ring.
            ShareBobbleView(snapshot: snapshot, side: side, theme: theme)
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
        if currentImage != nil {
            Button(action: presentShareSheet) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel(Text("Share"))
        } else {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.secondary)
        }
    }

    /// Presents the system share sheet directly (rather than `ShareLink`) for two reasons: it offers
    /// "Save Image" because the item is a real `UIImage`, and its completion handler tells us when an
    /// action finished, so this sheet can close itself. Cancelling leaves it open.
    private func presentShareSheet() {
        // Rebuilt from PNG data so the bobble's transparent background survives saving and copying.
        guard let png = currentImage?.pngData(), let image = UIImage(data: png),
              let presenter = Self.topViewController()
        else { return }

        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        let dismiss = self.dismiss
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            Task { @MainActor in dismiss() }
        }
        controller.popoverPresentationController?.sourceView = presenter.view
        presenter.present(controller, animated: true)
    }

    /// Top-most view controller of the key window, i.e. the controller hosting this sheet.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Renders both styles once at the screen's scale: the card at 1080 × 1350 px and the bobble at
    /// 1080 × 1080 px on a 3x device. The bobble keeps a transparent background.
    private func renderImages() {
        if cardImage == nil {
            let renderer = ImageRenderer(content: ShareCardView(snapshot: snapshot, theme: theme))
            renderer.scale = displayScale
            renderer.isOpaque = true
            cardImage = renderer.uiImage
        }
        if bobbleImage == nil {
            let renderer = ImageRenderer(
                content: ShareBobbleView(snapshot: snapshot, side: ShareBobbleView.overlaySide, theme: theme)
            )
            renderer.scale = displayScale
            renderer.isOpaque = false
            bobbleImage = renderer.uiImage
        }
    }
}
