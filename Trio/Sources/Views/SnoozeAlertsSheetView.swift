import SwiftUI
import Swinject

/// Shared "Snooze All" sheet. Used from Notifications settings and the home
/// glucose long-press. Wraps `TrioAlertManager.applySnooze` directly — no
/// router / module hop.
struct SnoozeAlertsSheetView: View {
    let resolver: Resolver
    @Binding var isPresented: Bool
    /// When set, a "Share" row is shown beneath the durations. Only the home screen provides it, since
    /// it needs the home view model's glucose data; the Settings entry point leaves it `nil`.
    var onShare: (() -> Void)?
    /// Same as `onShare`, with a seasonal look. When set, each of `ShareTheme.seasonal` gets its own row.
    var onShareSeasonal: ((ShareTheme) -> Void)?

    @State private var snoozeUntilDate: Date = .distantPast

    @Environment(\.colorScheme) var colorScheme
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            List {
                if snoozeUntilDate > Date() {
                    Section {
                        HStack {
                            Image(systemName: "moon.zzz.fill").foregroundStyle(.tint)
                            Text(String(
                                format: String(localized: "Snoozed until %@"),
                                snoozeUntilDate.formatted(date: .omitted, time: .shortened)
                            ))
                                .font(.headline)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            endSnoozeAction
                        }
                        .listRowBackground(Color.chart)
                    } footer: {
                        HStack {
                            Image(systemName: "hand.draw.fill").foregroundStyle(.primary)
                            Text("Swipe left to end snooze.")
                        }
                    }
                }
                Section(footer: Text(
                    "Pick a duration to mute every Trio alarm. Critical alerts (e.g. occlusion, urgent low) still pierce the snooze."
                )) {
                    ForEach(NotificationResponseAction.allCases, id: \.self) { action in
                        Button {
                            applySnooze(action.duration)
                        } label: {
                            HStack {
                                Text(action.localizedTitle).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                            }
                        }
                    }
                }.listRowBackground(Color.chart)

                if let onShare {
                    Section {
                        Button {
                            onShare()
                        } label: {
                            HStack {
                                Label {
                                    Text("Share").foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: "square.and.arrow.up").foregroundStyle(.tint)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                            }
                        }
                    }.listRowBackground(Color.chart)
                }

                if let onShareSeasonal {
                    Section {
                        ForEach(ShareTheme.seasonal, id: \.self) { theme in
                            Button {
                                onShareSeasonal(theme)
                            } label: {
                                HStack {
                                    Label {
                                        Text(theme.name).foregroundStyle(.primary)
                                    } icon: {
                                        Image(systemName: theme.systemImage).foregroundStyle(theme.iconColor)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.footnote)
                                }
                            }
                        }
                    }.listRowBackground(Color.chart)
                }
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Snooze Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { isPresented = false }
                }
            }
            .onAppear {
                snoozeUntilDate = UserDefaults.standard
                    .object(forKey: "UserNotificationsManager.snoozeUntilDate") as? Date ?? .distantPast
            }
        }
    }

    private var endSnoozeAction: some View {
        Button(role: .destructive) {
            endSnooze()
        } label: {
            Label("End Snooze", systemImage: "alarm.waves.left.and.right.fill")
        }
        .tint(.red)
    }

    private func applySnooze(_ duration: TimeInterval) {
        let trioAlertManager = resolver.resolve(TrioAlertManager.self)
        Task { @MainActor in
            await trioAlertManager?.applySnooze(for: duration)
            snoozeUntilDate = Date().addingTimeInterval(duration)
            isPresented = false
        }
    }

    private func endSnooze() {
        let trioAlertManager = resolver.resolve(TrioAlertManager.self)
        Task { @MainActor in
            await trioAlertManager?.applySnooze(for: 0)
            snoozeUntilDate = Date().addingTimeInterval(0)
        }
    }
}
