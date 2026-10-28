import Charts
import SwiftUI

/// Colors of a share image. `.standard` is Trio's own look; `.halloween` swaps in orange and black.
enum ShareTheme: Hashable {
    case standard
    case halloween

    var backgroundColors: [Color] {
        switch self {
        case .standard: return [Color.bgDarkBlue, Color.bgDarkerDarkBlue]
        case .halloween: return [Color(red: 0.16, green: 0.07, blue: 0.0), .black]
        }
    }

    /// Closed loop (first == last) so the angular gradient has no seam; `nil` keeps the standard ring.
    var ringColors: [Color]? {
        switch self {
        case .standard: return nil
        case .halloween: return [
                Color(red: 1.0, green: 0.62, blue: 0.1),
                Color(red: 1.0, green: 0.45, blue: 0.0),
                Color(red: 0.85, green: 0.3, blue: 0.0),
                Color(red: 1.0, green: 0.45, blue: 0.0),
                Color(red: 1.0, green: 0.62, blue: 0.1),
                Color(red: 1.0, green: 0.62, blue: 0.1)
            ]
        }
    }

    var accent: Color? {
        switch self {
        case .standard: return nil
        case .halloween: return Color(red: 1.0, green: 0.45, blue: 0.0)
        }
    }

    var ringFill: Color {
        switch self {
        case .standard: return Color.chart
        case .halloween: return .black
        }
    }

    /// Tint for the in-range band, grid lines and small captions.
    var highlight: Color {
        switch self {
        case .standard: return Color.loopGreen
        case .halloween: return Color(red: 1.0, green: 0.5, blue: 0.0)
        }
    }

    var brandColors: [Color] {
        switch self {
        case .standard: return Color.bobbleGradientColors
        case .halloween: return [Color(red: 1.0, green: 0.62, blue: 0.1), Color(red: 0.85, green: 0.3, blue: 0.0)]
        }
    }

    var brandText: String {
        switch self {
        case .standard: return "Trio"
        case .halloween: return "🎃 Trio 🎃"
        }
    }
}

/// Standalone card that is rendered to an image for sharing.
///
/// Laid out at 360 × 450 pt, which `ImageRenderer` turns into 1080 × 1350 px on a 3x screen
/// (4:5, the portrait ratio social apps expect). It is built only from a `ShareCardSnapshot`.
struct ShareCardView: View {
    static let size = CGSize(width: 360, height: 450)
    /// Side of the bobble on the card (its native canvas is 256 pt).
    private static let heroSide: CGFloat = 184

    let snapshot: ShareCardSnapshot
    var theme: ShareTheme = .standard

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                hero
                Spacer(minLength: 10)
                graph
                Spacer(minLength: 10)
                statsRow
                Spacer(minLength: 8)
                timestamps
                Spacer(minLength: 6)
                brandLabel
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        // The card is always dark so it looks the same no matter which appearance the phone is in.
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Glucose

    private var hero: some View {
        ShareBobbleView(snapshot: snapshot, side: Self.heroSide, theme: theme)
    }

    // MARK: - Graph

    private var graph: some View {
        let start = snapshot.graphStart
        let end = snapshot.capturedAt
        let low = snapshot.chartValue(snapshot.lowGlucose)
        let high = snapshot.chartValue(snapshot.highGlucose)

        return Chart {
            RectangleMark(
                xStart: .value("Start", start),
                xEnd: .value("End", end),
                yStart: .value("Low", low),
                yEnd: .value("High", high)
            )
            .foregroundStyle(theme.highlight.opacity(0.14))

            ForEach(snapshot.readings) { reading in
                PointMark(
                    x: .value("Time", reading.date),
                    y: .value("Glucose", snapshot.chartValue(Decimal(reading.mgdL)))
                )
                .foregroundStyle(pointColor(forMgdL: reading.mgdL))
                .symbolSize(24)
            }
        }
        .chartXScale(domain: start ... end)
        .chartYScale(domain: snapshot.graphYDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [low, high]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                AxisValueLabel()
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(height: 104)
    }

    /// Out-of-range points keep their glucose colors in every theme; in-range ones take the theme's tint.
    private func pointColor(forMgdL mgdL: Int) -> Color {
        let value = Decimal(mgdL)
        let inRange = value > snapshot.lowGlucose && value < snapshot.highGlucose
        return theme == .halloween && inRange ? theme.highlight : snapshot.color(forMgdL: mgdL)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(title: "IOB", value: iobText)
            stat(title: "COB", value: cobText)
            stat(title: "EVENTUAL", value: snapshot.eventualText ?? "--")
        }
    }

    private func stat(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var iobText: String {
        snapshot.iob.formatted(.number.precision(.fractionLength(2))) + " U"
    }

    private var cobText: String {
        guard let cob = snapshot.cob else { return "--" }
        return "\(cob) g"
    }

    // MARK: - Footer

    private var timestamps: some View {
        var text = String(localized: "Reading", comment: "Share card: time of the glucose reading")
            + " " + Self.timeFormatter.string(from: snapshot.readingDate)
        if snapshot.showsDeterminationDate, let date = snapshot.determinationDate {
            text += "  ·  " + String(localized: "Loop", comment: "Share card: time of the loop determination")
                + " " + Self.timeFormatter.string(from: date)
        }
        return Text(verbatim: text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var brandLabel: some View {
        Text(verbatim: theme.brandText)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(
                LinearGradient(colors: theme.brandColors, startPoint: .leading, endPoint: .trailing)
            )
    }
}

/// Trio's own contact-image bobble (ring, glucose number, trend triangle orbiting the ring), drawn at its
/// native 256 pt canvas and scaled to `side`. Used inside the card and on its own as a transparent
/// overlay image. Only the inside of the ring is filled, so the number stays readable over a photo.
struct ShareBobbleView: View {
    /// Side of the bobble-only image: 1080 × 1080 px on a 3x screen.
    static let overlaySide: CGFloat = 360

    let snapshot: ShareCardSnapshot
    let side: CGFloat
    var theme: ShareTheme = .standard

    var body: some View {
        let native = GlucoseBobbleContactView.Layout.nativeSize
        let ringDiameter = GlucoseBobbleContactView.Layout.ringDiameter
        let scale = side / native

        ZStack {
            Circle()
                .fill(theme.ringFill)
                .frame(width: ringDiameter, height: ringDiameter)

            GlucoseBobbleContactView(
                glucoseText: snapshot.glucoseText,
                // No "minutes ago" on a frozen image; the units take the line the bobble uses for the delta.
                minutesAgoText: nil,
                deltaText: snapshot.units.rawValue,
                glucoseColor: numberColor,
                rotationDegrees: snapshot.bobbleRotationDegrees,
                ringColors: theme.ringColors,
                accentColor: theme.accent
            )
        }
        .frame(width: native, height: native)
        .scaleEffect(scale)
        .frame(width: side, height: side)
        .environment(\.colorScheme, .dark)
    }

    /// In range the number is plain text (orange in Halloween); out of range it keeps its warning color.
    private var numberColor: Color {
        theme == .halloween && !snapshot.isOutOfRange ? theme.highlight : snapshot.glucoseColor
    }
}
