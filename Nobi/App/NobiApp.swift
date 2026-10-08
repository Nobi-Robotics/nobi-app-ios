import SwiftUI

/// Nobi Robotics — companion app for Kairo and the rest of the robot family.
@main
struct NobiApp: App {
    @StateObject private var fleet = NobiFleet()

    init() {
        NobiFont.register()
        NobiTheme.configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(fleet)
        }
    }
}

/// How the app looks: follow the phone, always paper, or always ink.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, paper, ink
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Match phone"
        case .paper: return "Paper (day)"
        case .ink: return "Ink (night)"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .paper: return .light
        case .ink: return .dark
        }
    }
}

/// Splash (ink-in logo) → main shell.
struct RootView: View {
    @AppStorage("nobi.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @State private var showSplash = true

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        ZStack {
            MainShellView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .tint(NobiTheme.ink)
        .preferredColorScheme(appearance.colorScheme)
    }
}
