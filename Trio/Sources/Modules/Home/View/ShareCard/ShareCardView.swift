import Charts
import SwiftUI

/// Standalone card that is rendered to an image for sharing.
///
/// Laid out at 360 × 450 pt, which `ImageRenderer` turns into 1080 × 1350 px on a 3x screen
/// (4:5, the portrait ratio social apps expect). It is built only from a `ShareCardSnapshot`.
struct ShareCardView: View {
    static let size = CGSize(width: 360, height: 450)

    let snapshot: ShareCardSnapshot

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue],
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
        ZStack {
            Circle()
                .stroke(AngularGradient.bobble, lineWidth: 8)
                .background(Circle().fill(Color.chart))
                .frame(width: 176, height: 176)

            VStack(spacing: 2) {
                Text(snapshot.glucoseText)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.glucoseColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    trendArrows
                    Text(snapshot.units.rawValue)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder private var trendArrows: some View {
        if let rotation = snapshot.trendRotation {
            HStack(spacing: 0) {
                ForEach(0 ..< snapshot.trendArrowCount, id: \.self) { _ in
                    Image(systemName: "arrow.right")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color.bobbleAccent)
                        .rotationEffect(.degrees(rotation))
                }
            }
        }
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
            .foregroundStyle(Color.loopGreen.opacity(0.14))

            ForEach(snapshot.readings) { reading in
                PointMark(
                    x: .value("Time", reading.date),
                    y: .value("Glucose", snapshot.chartValue(Decimal(reading.mgdL)))
                )
                .foregroundStyle(snapshot.color(forMgdL: reading.mgdL))
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
        Text(verbatim: "Trio")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(
                LinearGradient(colors: Color.bobbleGradientColors, startPoint: .leading, endPoint: .trailing)
            )
    }
}
