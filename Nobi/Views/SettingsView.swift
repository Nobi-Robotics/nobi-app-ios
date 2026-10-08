import SwiftUI

/// App settings — only what matters.
struct SettingsView: View {
    @EnvironmentObject var fleet: NobiFleet
    @Environment(\.colorScheme) private var scheme
    @AppStorage("nobi.appearance") private var appearanceRaw = AppAppearance.system.rawValue

    private var appearance: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        NobiPage(spacing: 26, topPadding: 4) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Appearance")
                    .font(NobiFont.body(13, .semibold))
                    .foregroundStyle(NobiTheme.ink3)
                    .padding(.leading, 6)
                InkSegmented(options: [(value: AppAppearance.system, title: "Auto"),
                                       (value: AppAppearance.paper, title: "Day"),
                                       (value: AppAppearance.ink, title: "Night")],
                             selection: appearance)
            }

            InkGroup(header: "Connection") {
                Toggle(isOn: $fleet.autoReconnect) {
                    rowText("Reconnect automatically")
                }
                .toggleStyle(InkToggleStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Rectangle().fill(NobiTheme.line).frame(height: 1).padding(.leading, 16)
                Toggle(isOn: $fleet.restoreImageAfterReconnect) {
                    rowText("Restore photo after restart")
                }
                .toggleStyle(InkToggleStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            VStack(spacing: 14) {
                Image(scheme == .dark ? "NobiMarkSticker" : "NobiMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                Image("NobiWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                Text("Little robots. Big hearts.")
                    .font(NobiFont.displayItalic(18))
                    .foregroundStyle(NobiTheme.ink2)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(NobiFont.body(12))
                    .foregroundStyle(NobiTheme.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rowText(_ text: String) -> some View {
        Text(text)
            .font(NobiFont.body(16, .medium))
            .foregroundStyle(NobiTheme.ink)
    }
}
