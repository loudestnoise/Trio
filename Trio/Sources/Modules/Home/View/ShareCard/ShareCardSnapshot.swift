import Foundation
import SwiftUI

/// Frozen copy of everything shown on the share card.
///
/// Built once from `Home.StateModel` when the glucose bobble is long-pressed. All values are copied into
/// plain value types, so the card neither changes nor touches Core Data while its sheet is open.
/// Nothing here fetches new data; it only re-reads what the home view model has already loaded.
struct ShareCardSnapshot: Identifiable {
    struct Reading: Identifiable {
        let id: Int
        let date: Date
        let mgdL: Int
    }

    /// Length of the glucose history drawn on the card.
    static let graphWindow: TimeInterval = 3 * 60 * 60

    let id = UUID()
    /// Colors to render with. Travels with the snapshot because the sheet that shows it can be
    /// built from a stale copy of the view's other state.
    var theme: ShareTheme = .standard
    /// Moment the snapshot was taken; the right edge of the graph.
    let capturedAt: Date

    let glucoseMgdL: Int
    let readingDate: Date
    let direction: BloodGlucose.Direction?
    let units: GlucoseUnits
    let lowGlucose: Decimal
    let highGlucose: Decimal
    let currentGlucoseTarget: Decimal
    let glucoseColorScheme: GlucoseColorScheme

    /// CGM and manual readings of the last three hours, oldest first.
    let readings: [Reading]

    let iob: Decimal
    let cob: Int?
    let eventualBG: Decimal?
    let determinationDate: Date?

    /// Returns `nil` when there is no glucose reading to share. Call from the main thread: the Core Data
    /// objects it reads belong to the view context.
    init?(state: Home.StateModel, now: Date = Date()) {
        guard let latest = state.latestTwoGlucoseValues.last, let readingDate = latest.date else {
            return nil
        }

        let windowStart = now.addingTimeInterval(-ShareCardSnapshot.graphWindow)
        var readings: [Reading] = []
        for (index, value) in state.glucoseFromPersistence.enumerated() {
            guard let date = value.date, date >= windowStart else { continue }
            readings.append(Reading(id: index, date: date, mgdL: Int(value.glucose)))
        }

        let determination = state.enactedAndNonEnactedDeterminations.first

        capturedAt = now
        glucoseMgdL = Int(latest.glucose)
        self.readingDate = readingDate
        direction = latest.directionEnum
        units = state.units
        lowGlucose = state.lowGlucose
        highGlucose = state.highGlucose
        currentGlucoseTarget = state.currentGlucoseTarget
        glucoseColorScheme = state.glucoseColorScheme
        self.readings = readings
        iob = state.currentIOB
        cob = determination.map { Int($0.cob) }
        eventualBG = determination?.eventualBG?.decimalValue
        determinationDate = determination?.deliverAt ?? determination?.timestamp
    }

    // MARK: - Display helpers

    /// Same text the bobble shows: "HIGH" at the 400 mg/dL ceiling, otherwise mg/dL or mmol/L.
    var glucoseText: String {
        if glucoseMgdL == 400 { return "HIGH" }
        return units == .mgdL ? Decimal(glucoseMgdL).description : Decimal(glucoseMgdL).formattedAsMmolL
    }

    var eventualText: String? {
        guard let eventualBG else { return nil }
        return units == .mgdL ? eventualBG.description : eventualBG.formattedAsMmolL
    }

    /// The loop determination time is only worth printing when it is not the same minute as the reading.
    var showsDeterminationDate: Bool {
        guard let determinationDate else { return false }
        return !Calendar.current.isDate(determinationDate, equalTo: readingDate, toGranularity: .minute)
    }

    /// Where the bobble's trend triangle sits on the ring, using the same mapping as the home bobble and
    /// the contact image: -90 is straight up, 0 flat, 90 straight down. Unknown trends read as flat.
    var bobbleRotationDegrees: Double {
        switch direction {
        case .doubleUp,
             .singleUp,
             .tripleUp:
            return -90
        case .fortyFiveUp:
            return -45
        case .fortyFiveDown:
            return 45
        case .doubleDown,
             .singleDown,
             .tripleDown:
            return 90
        default:
            return 0
        }
    }

    // MARK: - Graph helpers

    /// Converts a mg/dL value to the unit shown on the card.
    func chartValue(_ mgdL: Decimal) -> Double {
        let value = units == .mgdL ? mgdL : mgdL.asMmolL
        return NSDecimalNumber(decimal: value).doubleValue
    }

    var graphStart: Date { capturedAt.addingTimeInterval(-ShareCardSnapshot.graphWindow) }

    var graphYDomain: ClosedRange<Double> {
        let values = readings.map { chartValue(Decimal($0.mgdL)) } + [chartValue(lowGlucose), chartValue(highGlucose)]
        let lower = values.min() ?? 0
        let upper = values.max() ?? 1
        let padding = max((upper - lower) * 0.1, 1)
        return (lower - padding) ... (upper + padding)
    }

    // MARK: - Colors

    /// Same dynamic coloring as the main chart's points and the bobble.
    func color(forMgdL mgdL: Int) -> Color {
        // TODO: same workaround as the bobble: fixed 55/220 bounds for the dynamic color shades
        let hardCodedLow = Decimal(55)
        let hardCodedHigh = Decimal(220)
        let isDynamicColorScheme = glucoseColorScheme == .dynamicColor
        return Trio.getDynamicGlucoseColor(
            glucoseValue: Decimal(mgdL),
            highGlucoseColorValue: isDynamicColorScheme ? hardCodedHigh : highGlucose,
            lowGlucoseColorValue: isDynamicColorScheme ? hardCodedLow : lowGlucose,
            targetGlucose: currentGlucoseTarget,
            glucoseColorScheme: glucoseColorScheme
        )
    }

    /// The big number is plain text in range and colored outside of it, like on the bobble.
    var glucoseColor: Color {
        guard !isOutOfRange else { return color(forMgdL: glucoseMgdL) }
        return Color.primary
    }

    var isOutOfRange: Bool {
        let value = Decimal(glucoseMgdL)
        return value <= lowGlucose || value >= highGlucose
    }
}
