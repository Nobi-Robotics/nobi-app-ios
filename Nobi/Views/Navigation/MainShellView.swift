import SwiftUI

/// Three places, nothing more.
enum AppTab: String, CaseIterable, Identifiable {
    case home, create, robots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .create: return "Create"
        case .robots: return "Robots"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .create: return "sparkles"
        case .robots: return "square.stack"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .create: return "sparkles"
        case .robots: return "square.stack.fill"
        }
    }
}

/// Pages pushed inside a tab.
enum Route: Hashable {
    case games
    case focus
    case goals
    case reminders
    case music
    case robot(UUID)
    case robotDetails(UUID)
    case settings
    case comingSoon
}

/// Shell-level actions any screen can trigger.
struct ShellActions {
    var openPairing: () -> Void = {}
    var openSwitcher: () -> Void = {}
    var goTo: (AppTab) -> Void = { _ in }
}

private struct ShellActionsKey: EnvironmentKey {
    static let defaultValue = ShellActions()
}

extension EnvironmentValues {
    var shell: ShellActions {
        get { self[ShellActionsKey.self] }
        set { self[ShellActionsKey.self] = newValue }
    }
}

struct MainShellView: View {
    @EnvironmentObject var fleet: NobiFleet

    @State private var tab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var createPath = NavigationPath()
    @State private var robotsPath = NavigationPath()
    @State private var showSwitcher = false
    @State private var showPairing = false

    var body: some View {
        ZStack {
            switch tab {
            case .home:
                NavigationStack(path: $homePath) { root(for: .home) }
            case .create:
                NavigationStack(path: $createPath) { root(for: .create) }
            case .robots:
                NavigationStack(path: $robotsPath) { root(for: .robots) }
            }
        }
        .overlay(alignment: .bottom) {
            NobiTabBar(selection: $tab)
                .ignoresSafeArea(.keyboard)
        }
        .environment(\.shell, actions)
        .sheet(isPresented: $showSwitcher) {
            RobotSwitcherSheet()
                .environmentObject(fleet)
                .environment(\.shell, actions)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPairing) {
            PairingSheet()
                .environmentObject(fleet)
                .presentationCornerRadius(28)
        }
    }

    private var actions: ShellActions {
        ShellActions(
            openPairing: {
                showSwitcher = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showPairing = true }
            },
            openSwitcher: { showSwitcher = true },
            goTo: { t in
                showSwitcher = false
                tab = t
            }
        )
    }

    @ViewBuilder
    private func root(for tab: AppTab) -> some View {
        Group {
            switch tab {
            case .home:
                if let robot = fleet.activeRobot {
                    HomeView().environmentObject(robot).id(robot.id)
                } else {
                    WelcomeView()
                }
            case .create:
                if let robot = fleet.activeRobot {
                    CreateView().environmentObject(robot).id(robot.id)
                } else {
                    NoRobotView()
                }
            case .robots:
                RobotsView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { PageTopBar() }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: NobiTabBar.reservedHeight) }
        .background { PaperBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Route.self) { route in
            destination(route)
                .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: NobiTabBar.reservedHeight) }
                .background { PaperBackground() }
                .toolbar(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .games:
            if let r = fleet.activeRobot { PlayView().environmentObject(r) }
        case .focus:
            if let r = fleet.activeRobot { FocusView().environmentObject(r) }
        case .goals:
            if let r = fleet.activeRobot { GoalsView().environmentObject(r) }
        case .reminders:
            if let r = fleet.activeRobot { RemindersView().environmentObject(r) }
        case .music:
            if let r = fleet.activeRobot { MusicView().environmentObject(r) }
        case .robot(let id):
            if let r = fleet.robot(id) { RobotDetailView().environmentObject(r) }
        case .robotDetails(let id):
            if let r = fleet.robot(id) { RobotDiagnosticsView().environmentObject(r) }
        case .settings:
            SettingsView()
        case .comingSoon:
            ComingSoonView()
        }
    }
}

// MARK: - Tab bar

struct NobiTabBar: View {
    @Binding var selection: AppTab

    /// Space pages leave at the bottom so nothing hides under the floating bar.
    static let reservedHeight: CGFloat = 76

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { t in
                let selected = selection == t
                Button {
                    selection = t
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selected ? t.selectedIcon : t.icon)
                            .font(.system(size: 18, weight: selected ? .semibold : .regular))
                        Text(t.title)
                            .font(NobiFont.body(11, selected ? .semibold : .medium))
                    }
                    .foregroundStyle(selected ? NobiTheme.ink : NobiTheme.ink3)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(NobiTheme.card.opacity(0.88)))
                .shadow(color: NobiTheme.softShadow, radius: 20, y: 8)
        )
        .overlay(Capsule(style: .continuous).strokeBorder(NobiTheme.line, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: selection)
        .padding(.horizontal, 48)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

// MARK: - Top bar

/// Brand mark on the left, day / night switch on the right. Sits on top of every main page.
struct PageTopBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("NobiMarkSticker")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            Image("NobiWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .accessibilityLabel("Nobi Robotics")
            Spacer()
            DayNightToggle()
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(NobiTheme.paper.opacity(0.65))
                .ignoresSafeArea(edges: .top)
        }
    }
}

/// Sun / moon switch. Picks Day or Night explicitly ("Auto" lives in Settings).
struct DayNightToggle: View {
    @AppStorage("nobi.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @Environment(\.colorScheme) private var scheme
    @Namespace private var thumb

    private var isNight: Bool { scheme == .dark }

    var body: some View {
        HStack(spacing: 2) {
            segment(icon: "sun.max.fill", label: "Day", selected: !isNight) {
                appearanceRaw = AppAppearance.paper.rawValue
            }
            segment(icon: "moon.fill", label: "Night", selected: isNight) {
                appearanceRaw = AppAppearance.ink.rawValue
            }
        }
        .padding(3)
        .background(Capsule().fill(NobiTheme.paper2))
        .overlay(Capsule().strokeBorder(NobiTheme.line, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: isNight)
    }

    private func segment(icon: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.35)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? NobiTheme.paper : NobiTheme.ink3)
                .frame(width: 38, height: 30)
                .background {
                    if selected {
                        Capsule().fill(NobiTheme.ink).matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
