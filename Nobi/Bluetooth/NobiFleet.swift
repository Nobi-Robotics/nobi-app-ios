import Combine
import CoreBluetooth
import Foundation

/// The robot family: owns the one `CBCentralManager`, keeps every paired robot connected,
/// and fans commands out to one robot or to the whole sync group.
final class NobiFleet: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var bluetooth: BluetoothAvailability = .unknown
    @Published private(set) var robots: [NobiRobot] = []
    @Published private(set) var nearby: [DiscoveredDevice] = []
    @Published private(set) var isScanning = false

    @Published var activeRobotID: UUID? {
        didSet { defaults.set(activeRobotID?.uuidString, forKey: Keys.activeRobot) }
    }

    /// When on, content (faces, words, photos, notes, focus, games…) goes to every connected robot in `syncMembers`.
    @Published var syncEnabled: Bool {
        didSet { defaults.set(syncEnabled, forKey: Keys.syncEnabled) }
    }

    @Published var syncMembers: Set<UUID> {
        didSet { defaults.set(syncMembers.map(\.uuidString), forKey: Keys.syncMembers) }
    }

    @Published var autoReconnect: Bool {
        didSet { defaults.set(autoReconnect, forKey: Keys.autoReconnect) }
    }

    @Published var restoreImageAfterReconnect: Bool {
        didSet { defaults.set(restoreImageAfterReconnect, forKey: Keys.restoreImage) }
    }

    @Published var textHistory: [String] {
        didSet { defaults.set(Array(textHistory.prefix(20)), forKey: Keys.textHistory) }
    }

    // MARK: - Private

    private enum Keys {
        static let profiles = "nobi.fleet.profiles"
        static let activeRobot = "nobi.fleet.activeRobot"
        static let syncEnabled = "nobi.fleet.syncEnabled"
        static let syncMembers = "nobi.fleet.syncMembers"
        static let autoReconnect = "nobi.autoReconnect"
        static let restoreImage = "nobi.restoreImage"
        static let textHistory = "nobi.textHistory"
        // Prototype (single robot) keys, migrated once.
        static let legacyPeripheral = "nobi.lastPeripheralID"
        static let legacyBitmap = "nobi.savedBitmap"
        static let legacyPetName = "nobi.pet.name"
        static let legacyPoints = "nobi.pet.pandaPoints"
        static let legacyPets = "nobi.pet.totalPets"
        static let legacyFeeds = "nobi.pet.totalFeedings"
        static let legacyMood = "nobi.pet.lastMood"
    }

    private let defaults = UserDefaults.standard
    private var central: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var scanStopTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    /// Saved robots we are actively looking for during a scan.
    private var wanted: Set<UUID> = []

    // MARK: - Init

    override init() {
        let d = UserDefaults.standard
        self.syncEnabled = (d.object(forKey: Keys.syncEnabled) as? Bool) ?? false
        self.syncMembers = Set((d.stringArray(forKey: Keys.syncMembers) ?? []).compactMap(UUID.init(uuidString:)))
        self.autoReconnect = (d.object(forKey: Keys.autoReconnect) as? Bool) ?? true
        self.restoreImageAfterReconnect = (d.object(forKey: Keys.restoreImage) as? Bool) ?? false
        self.textHistory = d.stringArray(forKey: Keys.textHistory) ?? []
        self.activeRobotID = d.string(forKey: Keys.activeRobot).flatMap(UUID.init(uuidString:))
        super.init()

        var profiles: [RobotProfile] = []
        if let data = d.data(forKey: Keys.profiles),
           let decoded = try? JSONDecoder().decode([RobotProfile].self, from: data) {
            profiles = decoded
        } else if let legacy = Self.migrateLegacyProfile(d) {
            profiles = [legacy]
        }
        robots = profiles.map { NobiRobot(profile: $0, fleet: self) }
        if activeRobotID == nil || !robots.contains(where: { $0.id == activeRobotID }) {
            activeRobotID = robots.first?.id
        }
        saveProfiles()

        central = CBCentralManager(delegate: self, queue: nil)

        // Resync every robot's clock when the phone changes time zone (Spec §8/§27).
        NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)
            .sink { [weak self] _ in
                self?.connectedRobots.forEach { $0.syncTime() }
            }
            .store(in: &cancellables)
    }

    private static func migrateLegacyProfile(_ d: UserDefaults) -> RobotProfile? {
        guard let idString = d.string(forKey: Keys.legacyPeripheral),
              let uuid = UUID(uuidString: idString) else { return nil }
        var name = d.string(forKey: Keys.legacyPetName) ?? "Kairo"
        if name.isEmpty || name == "Nobi" { name = "Kairo" }
        var p = RobotProfile(id: uuid, name: name, plate: .yellow, hardwareName: NobiProtocol.deviceName, addedAt: Date())
        if d.object(forKey: Keys.legacyPoints) != nil { p.bondXP = d.integer(forKey: Keys.legacyPoints) }
        p.totalPets = d.integer(forKey: Keys.legacyPets)
        p.totalFeedings = d.integer(forKey: Keys.legacyFeeds)
        if let m = d.string(forKey: Keys.legacyMood) { p.lastMood = m }
        p.savedBitmap = d.data(forKey: Keys.legacyBitmap)
        return p
    }

    // MARK: - Persistence

    func saveProfiles() {
        let profiles = robots.map(\.profile)
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Keys.profiles)
        }
    }

    /// Robots call this when their link changes so fleet-wide views (targets, counts) refresh.
    func robotLinkChanged(_ robot: NobiRobot) {
        objectWillChange.send()
    }

    // MARK: - Queries

    var activeRobot: NobiRobot? {
        robots.first { $0.id == activeRobotID } ?? robots.first
    }

    var connectedRobots: [NobiRobot] { robots.filter(\.isConnected) }

    func robot(_ id: UUID) -> NobiRobot? { robots.first { $0.id == id } }

    func isInSyncGroup(_ robot: NobiRobot) -> Bool {
        robot.id == activeRobot?.id || syncMembers.contains(robot.id)
    }

    /// The robots a command goes to right now.
    var targets: [NobiRobot] {
        guard let active = activeRobot else { return [] }
        if syncEnabled {
            return robots.filter { $0.isConnected && ($0.id == active.id || syncMembers.contains($0.id)) }
        }
        return active.isConnected ? [active] : []
    }

    var canSend: Bool { !targets.isEmpty }

    /// Sync mode is only meaningful with two or more robots in the family.
    var canSync: Bool { robots.count > 1 }

    var isBroadcasting: Bool { syncEnabled && targets.count > 1 }

    /// "Kairo", "Kairo & Mochi", "3 robots"
    var targetSummary: String {
        let t = targets
        switch t.count {
        case 0: return activeRobot.map { "\($0.name) (offline)" } ?? "no robot yet"
        case 1: return t[0].name
        case 2: return "\(t[0].name) & \(t[1].name)"
        default: return "\(t.count) robots"
        }
    }

    /// Runs a command on every target robot.
    func perform(_ action: (NobiRobot) -> Void) {
        targets.forEach(action)
    }

    // MARK: - Choosing robots

    func setActive(_ robot: NobiRobot) {
        activeRobotID = robot.id
    }

    func toggleSyncMember(_ robot: NobiRobot) {
        if syncMembers.contains(robot.id) {
            syncMembers.remove(robot.id)
        } else {
            syncMembers.insert(robot.id)
        }
    }

    func rename(_ robot: NobiRobot, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        robot.profile.name = String(clean.prefix(24))
    }

    func setPlate(_ robot: NobiRobot, _ plate: FacePlate) {
        robot.profile.plate = plate
    }

    /// Suggests a friendly unused name for a new robot.
    func suggestedName(for plate: FacePlate) -> String {
        let base = robots.isEmpty ? "Kairo" : (plate == .white ? "Mochi" : "Kairo")
        let taken = Set(robots.map { $0.name.lowercased() })
        if !taken.contains(base.lowercased()) { return base }
        var n = 2
        while taken.contains("\(base.lowercased()) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    // MARK: - Scanning

    func startScan(duration: TimeInterval = 20) {
        guard bluetooth.isReady else { return }
        nearby.removeAll()
        central.scanForPeripherals(withServices: [NobiProtocol.service], options: nil)
        isScanning = true
        scanStopTimer?.invalidate()
        scanStopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopScan()
        }
    }

    func stopScan() {
        scanStopTimer?.invalidate()
        scanStopTimer = nil
        if bluetooth.isReady { central.stopScan() }
        isScanning = false
        wanted.removeAll()
    }

    // MARK: - Pair / connect / disconnect / forget

    /// Adds a newly found robot to the family and connects to it.
    @discardableResult
    func pair(_ device: DiscoveredDevice, name: String, plate: FacePlate) -> NobiRobot {
        if let existing = robot(device.id) {
            connect(existing, userInitiated: true)
            return existing
        }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = RobotProfile(
            id: device.id,
            name: clean.isEmpty ? suggestedName(for: plate) : String(clean.prefix(24)),
            plate: plate,
            hardwareName: device.name,
            addedAt: Date()
        )
        let robot = NobiRobot(profile: profile, fleet: self)
        robots.append(robot)
        syncMembers.insert(robot.id)
        activeRobotID = robot.id
        nearby.removeAll { $0.id == device.id }
        saveProfiles()
        connect(robot, userInitiated: true)
        return robot
    }

    func connect(_ robot: NobiRobot, userInitiated: Bool = true) {
        guard bluetooth.isReady else { return }
        let p = robot.peripheral
            ?? discoveredPeripherals[robot.id]
            ?? central.retrievePeripherals(withIdentifiers: [robot.id]).first
        guard let p else {
            // iOS doesn't know this robot any more — find it by scanning.
            wanted.insert(robot.id)
            robot.willConnect(userInitiated: false)
            if !isScanning { startScan() }
            return
        }
        robot.attach(p)
        robot.willConnect(userInitiated: userInitiated)
        central.connect(p, options: nil)
    }

    func connectAll() {
        robots.filter { !$0.isConnected }.forEach { connect($0, userInitiated: false) }
    }

    func disconnect(_ robot: NobiRobot) {
        robot.userInitiatedDisconnect = true
        wanted.remove(robot.id)
        if let p = robot.peripheral {
            central.cancelPeripheralConnection(p)
        }
        robot.markOffline()
    }

    func forget(_ robot: NobiRobot) {
        disconnect(robot)
        robots.removeAll { $0.id == robot.id }
        syncMembers.remove(robot.id)
        if activeRobotID == robot.id { activeRobotID = robots.first?.id }
        saveProfiles()
    }

    /// Pushes the active robot's look (brightness, text size, image scale, face or life mode, clock, photo)
    /// to every other connected robot in the sync group.
    func matchEveryone(to source: NobiRobot) {
        let s = source.deviceState
        for r in robots where r.id != source.id && r.isConnected && isInSyncGroup(r) {
            r.sendBrightness(s.brightness)
            r.sendTextSize(s.textSize)
            r.sendImageScale(s.imageScale)
            r.syncTime()
            if s.lifeModeEnabled {
                r.sendLifeMode(enabled: true)
            } else {
                r.sendEmotionName(s.emotion)
            }
            if s.hasImage, let bitmap = source.profile.savedBitmap {
                r.beginImageTransfer(bitmap: bitmap)
            }
        }
    }

    func recordText(_ text: String) {
        let clean = NobiProtocol.sanitizeText(text)
        guard !clean.isEmpty else { return }
        var h = textHistory
        h.removeAll { $0 == clean }
        h.insert(clean, at: 0)
        textHistory = Array(h.prefix(20))
    }
}

// MARK: - CBCentralManagerDelegate

extension NobiFleet: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bluetooth = .poweredOn
            if autoReconnect { connectAll() }
        case .poweredOff:
            bluetooth = .poweredOff
            isScanning = false
            robots.forEach { $0.bluetoothWentAway() }
        case .unauthorized:
            bluetooth = .unauthorized
            robots.forEach { $0.bluetoothWentAway() }
        case .unsupported:
            bluetooth = .unsupported
        default:
            bluetooth = .unknown
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discoveredPeripherals[peripheral.identifier] = peripheral

        // A robot that's already family: connect if we're looking for it.
        if let known = robot(peripheral.identifier) {
            if !known.isConnected, known.link != .connecting,
               wanted.contains(known.id) || (autoReconnect && !known.userInitiatedDisconnect) {
                wanted.remove(known.id)
                connect(known, userInitiated: true)
            }
            return
        }

        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? NobiProtocol.deviceName
        let entry = DiscoveredDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let i = nearby.firstIndex(where: { $0.id == entry.id }) {
            nearby[i] = entry
        } else {
            nearby.append(entry)
        }
        nearby.sort { $0.rssi > $1.rssi }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let robot = robot(peripheral.identifier) else {
            // Connected to something we then forgot — let it go.
            central.cancelPeripheralConnection(peripheral)
            return
        }
        robot.attach(peripheral)
        robot.didConnect()
        if robots.count == 1 { activeRobotID = robot.id }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        robot(peripheral.identifier)?.didFailToConnect(error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let robot = robot(peripheral.identifier) else { return }
        let shouldReconnect = robot.didDisconnect(error)
        if shouldReconnect && autoReconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak robot] in
                guard let self, let robot, !robot.userInitiatedDisconnect, !robot.isConnected,
                      self.robots.contains(where: { $0.id == robot.id }) else { return }
                // A pending connect: iOS completes it whenever the robot comes back in range.
                self.connect(robot, userInitiated: false)
            }
        }
    }
}
