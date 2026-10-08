import CoreBluetooth
import Foundation

/// One robot in the family: its Bluetooth link, live state and everything it can be told to do.
///
/// The fleet (`NobiFleet`) owns the single `CBCentralManager` and hands each robot its peripheral;
/// the robot is the peripheral's delegate. Everything runs on the main queue.
/// Fully compliant with the Nobi firmware v0.6.3 protocol.
final class NobiRobot: NSObject, ObservableObject, Identifiable {

    let id: UUID

    @Published var profile: RobotProfile {
        didSet {
            if profile != oldValue { fleet?.saveProfiles() }
        }
    }

    @Published private(set) var link: RobotLink = .offline {
        didSet {
            if link != oldValue { fleet?.robotLinkChanged(self) }
        }
    }

    @Published var deviceState = NobiDeviceState.empty
    @Published private(set) var protocolLog: [String] = []
    @Published private(set) var imageTransferState: ImageTransferState = .idle
    @Published private(set) var pingResult: String = ""
    @Published private(set) var rssi: Int?

    // Kairo v0.7 features
    @Published var goals = KairoGoalsState()
    @Published var reminders: KairoReminders?
    @Published var focusCycle = FocusCycleState()
    @Published private(set) var isFinding = false
    @Published var music = KairoMusicState()

    weak var fleet: NobiFleet?

    private(set) var peripheral: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private var txChar: CBCharacteristic?
    private var imageChar: CBCharacteristic?

    private let proximityMonitor = NobiProximityMonitor()
    private var reconcileTimer: Timer?
    private var connectTimer: Timer?

    /// Set when the user taps Disconnect / Forget so we don't auto-reconnect.
    var userInitiatedDisconnect = false

    // Image transfer queue
    private var pendingBitmap: Data?
    private var pendingOffset = 0
    private var awaitingImageReceived = false
    private var imageWatchdog: Timer?
    private var pendingRestoreCheck = false

    init(profile: RobotProfile, fleet: NobiFleet?) {
        self.id = profile.id
        self.profile = profile
        self.fleet = fleet
        super.init()
    }

    // MARK: - Convenience

    var name: String { profile.name }
    var isConnected: Bool { link == .connected }

    /// The face the app should draw for this robot right now.
    var currentEmotion: NobiEmotion {
        if deviceState.sleeping { return .sleepy }
        if isConnected, let e = NobiEmotion(rawValue: deviceState.emotion.lowercased()) { return e }
        return profile.lastEmotion
    }

    /// Goals, reminders, focus cycles and Find need Kairo firmware 0.7 or newer.
    var supportsKairoFeatures: Bool {
        NobiProtocol.firmware(profile.lastFirmware ?? deviceState.firmware, atLeast: 0, 7)
    }

    /// 0...3 signal bars from the latest RSSI reading.
    var signalBars: Int {
        guard isConnected, let rssi else { return 0 }
        if rssi >= -60 { return 3 }
        if rssi >= -72 { return 2 }
        if rssi >= -85 { return 1 }
        return 0
    }

    // MARK: - Link lifecycle (called by the fleet)

    func attach(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
    }

    func willConnect(userInitiated: Bool) {
        userInitiatedDisconnect = false
        connectTimer?.invalidate()
        if userInitiated {
            link = .connecting
            log("Connecting to \(name)…")
            // After a while we stop "connecting" and keep a quiet pending connection instead.
            connectTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
                guard let self, self.link == .connecting else { return }
                self.log("\(self.name) isn't answering yet — will connect when it's in range")
                self.link = .searching
            }
        } else if link != .connected {
            link = .searching
        }
    }

    func markOffline() {
        connectTimer?.invalidate()
        if link != .connected { link = .offline }
    }

    func didConnect() {
        connectTimer?.invalidate()
        pendingRestoreCheck = false
        link = .connected
        if !imageTransferState.isActive { imageTransferState = .idle }
        log("Connected — discovering services…")
        peripheral?.discoverServices([NobiProtocol.service])
    }

    func didFailToConnect(_ error: Error?) {
        connectTimer?.invalidate()
        link = .offline
        log("Failed to connect: \(error?.localizedDescription ?? "unknown")")
    }

    /// Returns true when the fleet should try to reconnect.
    func didDisconnect(_ error: Error?) -> Bool {
        connectTimer?.invalidate()
        abortImageTransfer(reason: "disconnected during transfer")
        stopReconcile()
        proximityMonitor.stop()
        pendingRestoreCheck = false
        commandChar = nil
        txChar = nil
        imageChar = nil
        rssi = nil
        link = .offline
        log("Disconnected\(error.map { ": \($0.localizedDescription)" } ?? "")")
        return !userInitiatedDisconnect
    }

    func bluetoothWentAway() {
        abortImageTransfer(reason: "Bluetooth off")
        stopReconcile()
        proximityMonitor.stop()
        connectTimer?.invalidate()
        commandChar = nil
        txChar = nil
        imageChar = nil
        rssi = nil
        link = .offline
    }

    // MARK: - Logging

    private func log(_ line: String, direction: String = "") {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = direction.isEmpty ? "[\(stamp)] \(line)" : "[\(stamp)] \(direction) \(line)"
        protocolLog.append(entry)
        if protocolLog.count > 300 {
            protocolLog.removeFirst(protocolLog.count - 300)
        }
    }

    func clearLog() {
        protocolLog.removeAll()
    }

    // MARK: - Command transport

    private var canSendCommand: Bool {
        peripheral != nil && commandChar != nil && link == .connected
    }

    private func writeCommand(_ command: String) {
        guard let p = peripheral, let c = commandChar, link == .connected else {
            log("Not connected — cannot send: \(command)")
            return
        }
        guard let data = command.data(using: .utf8) else { return }
        log(command, direction: "→")
        p.writeValue(data, for: c, type: .withResponse)
    }

    // MARK: - Post-connection handshake (Spec §5)

    private func executePostConnectionHandshake() {
        log("Saying hello…")
        sendPing()
        syncTime()
        requestStatus()
        requestLifeStats()
        requestGameScores()
        requestGoals()
        requestReminders()
        requestMusic()

        if let p = peripheral {
            proximityMonitor.start(peripheral: p) { [weak self] zone in
                self?.sendProximity(zone)
            }
        }
        startReconcile()
    }

    private func startReconcile() {
        stopReconcile()
        // Spec §47: reconcile every 15 seconds
        reconcileTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self, self.link == .connected else { return }
            self.requestStatus()
            if self.deviceState.focusActive {
                self.requestPomodoroStatus()
            }
        }
    }

    private func stopReconcile() {
        reconcileTimer?.invalidate()
        reconcileTimer = nil
    }

    // MARK: - Care (app-side bond + firmware petting)

    @discardableResult
    func stroke() -> String {
        profile.totalPets += 1
        profile.bondXP += 5
        profile.lastMood = NobiEmotion.love.rawValue
        if isConnected { pet() }
        return "\(name) loved that! +5 XP"
    }

    @discardableResult
    func feed(_ snack: NobiSnack) -> String {
        profile.totalFeedings += 1
        profile.bondXP += snack.xpEarned
        profile.lastMood = NobiEmotion.excited.rawValue
        if isConnected { pet() }
        return "Nom nom! \(snack.title) · +\(snack.xpEarned) XP"
    }

    func noteMood(_ emotion: NobiEmotion) {
        profile.lastMood = emotion.rawValue
    }

    // MARK: - Time sync (Spec §8/§27)

    func syncTime() {
        let unix = Int(Date().timeIntervalSince1970)
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        writeCommand(NobiProtocol.timeSync(unix: unix, offsetMinutes: offsetMinutes))
    }

    // MARK: - Basic & control commands

    func sendPing() {
        pingResult = "…"
        writeCommand(NobiProtocol.ping)
    }

    func requestStatus() { writeCommand(NobiProtocol.status) }

    func sendFace() { writeCommand(NobiProtocol.face) }

    func sendEmotion(_ emotion: NobiEmotion) {
        sendEmotionName(emotion.rawValue)
        noteMood(emotion)
    }

    func sendEmotionName(_ name: String) {
        writeCommand(NobiProtocol.emotion(name))
        // A manual emotion turns Life Mode off on the firmware.
        deviceState.emotion = name
        deviceState.lifeModeEnabled = false
    }

    func sendBrightness(_ value: Int) {
        writeCommand(NobiProtocol.brightness(value))
    }

    // MARK: - Text (Spec §12/§13)

    func sendTextSize(_ size: Int) {
        let clamped = min(3, max(1, size))
        writeCommand(NobiProtocol.textSize(clamped))
        deviceState.textSize = clamped
    }

    /// Sends text_size before text so the OLED font is right (Spec §12).
    func sendText(_ message: String, size: Int? = nil) {
        if let targetSize = size, targetSize != deviceState.textSize {
            sendTextSize(targetSize)
        }
        writeCommand(NobiProtocol.text(message))
    }

    /// Sends text_size before the notification card (Spec §14).
    func sendNotification(app: String, title: String, message: String, size: Int? = nil) {
        if let targetSize = size, targetSize != deviceState.textSize {
            sendTextSize(targetSize)
        }
        writeCommand(NobiProtocol.notify(app: app, title: title, message: message))
    }

    // MARK: - Image scale & controls (Spec §18-§21)

    func sendImageScale(_ percent: Int) {
        let clamped = min(200, max(25, percent))
        writeCommand(NobiProtocol.imageScale(clamped))
        deviceState.imageScale = clamped
    }

    func showImage() { writeCommand(NobiProtocol.imageShow) }
    func clearImage() { writeCommand(NobiProtocol.imageClear) }

    // MARK: - Life mode & petting (Spec §23-§26)

    func sendLifeMode(enabled: Bool) {
        writeCommand(enabled ? NobiProtocol.lifeOn : NobiProtocol.lifeOff)
    }

    func requestLifeStats() { writeCommand(NobiProtocol.lifeStats) }
    func pet() { writeCommand(NobiProtocol.pet) }
    func sleep() { writeCommand(NobiProtocol.sleep) }
    func wake() { writeCommand(NobiProtocol.wake) }

    // MARK: - Focus (Spec §30-§31)

    func startFocus(minutes: Int) { writeCommand(NobiProtocol.pomodoroStart(minutes: minutes)) }
    func stopFocus() { writeCommand(NobiProtocol.pomodoroStop) }
    func requestPomodoroStatus() { writeCommand(NobiProtocol.pomodoroStatus) }

    // MARK: - Kairo v0.7: focus cycles

    /// Work / break rounds. Kairo celebrates with its buzzer after every work session.
    func startFocusCycle(work: Int, breakMinutes: Int, rounds: Int) {
        writeCommand(NobiProtocol.pomodoroCycle(work: work, breakMinutes: breakMinutes, rounds: rounds))
        focusCycle.workMinutes = work
        focusCycle.breakMinutes = breakMinutes
        focusCycle.rounds = rounds
        focusCycle.round = 1
        focusCycle.isBreak = false
    }

    func skipFocusPhase() { writeCommand(NobiProtocol.pomodoroSkip) }

    // MARK: - Kairo v0.7: daily goals

    func requestGoals() { writeCommand(NobiProtocol.goals) }

    func setGoal(slot: Int, kind: GoalKind, target: Int, label: String) {
        writeCommand(NobiProtocol.goalSet(slot: slot, kind: kind, target: target, label: label))
        let keepProgress = goals.slots[slot]?.kind == kind ? (goals.slots[slot]?.progress ?? 0) : 0
        goals.slots[slot] = KairoGoal(slot: slot, kind: kind, label: label.isEmpty ? kind.shortLabel : label,
                                      progress: keepProgress, target: target)
    }

    func clearGoal(slot: Int) {
        writeCommand(NobiProtocol.goalClear(slot: slot))
        goals.slots[slot] = nil
    }

    func addGoalProgress(slot: Int, delta: Int) {
        writeCommand(NobiProtocol.goalAdd(slot: slot, delta: delta))
        if var g = goals.slots[slot] {
            g.progress = max(0, min(99, g.progress + delta))
            goals.slots[slot] = g
        }
    }

    func showGoalsOnRobot() { writeCommand(NobiProtocol.goalsShow) }

    // MARK: - Kairo v0.7: reminders, quiet hours, sound

    func requestReminders() { writeCommand(NobiProtocol.reminders) }

    func setReminder(_ kind: ReminderKind, _ setting: ReminderSetting) {
        writeCommand(NobiProtocol.remindSet(kind, setting))
        if reminders == nil { reminders = KairoReminders() }
        reminders?[kind] = setting
    }

    func testReminder(_ kind: ReminderKind) { writeCommand(NobiProtocol.remindTest(kind)) }

    func setQuietHours(enabled: Bool, start: Int, end: Int) {
        writeCommand(NobiProtocol.quietSet(enabled: enabled, start: start, end: end))
        if reminders == nil { reminders = KairoReminders() }
        reminders?.quietEnabled = enabled
        reminders?.quietStart = start
        reminders?.quietEnd = end
    }

    func setSound(_ on: Bool) {
        writeCommand(NobiProtocol.sound(on))
        if reminders == nil { reminders = KairoReminders() }
        reminders?.sound = on
    }

    // MARK: - Kairo v0.7: invert colours

    /// Dark eyes on a lit screen (hardware inversion on the OLED).
    func setInverted(_ on: Bool) {
        writeCommand(NobiProtocol.invert(on))
        deviceState.inverted = on
    }

    // MARK: - Kairo v0.7: hold mode

    /// Keep whatever is on screen (face, words, note, photo) until it's changed.
    func setHold(_ on: Bool) {
        writeCommand(on ? NobiProtocol.holdOn : NobiProtocol.holdOff)
        deviceState.hold = on
    }

    // MARK: - Kairo v0.7: music

    func requestMusic() { writeCommand(NobiProtocol.music) }

    func playSong(_ index: Int) {
        writeCommand(NobiProtocol.musicPlay(index))
        music.song = index
        music.playing = true
    }

    func stopMusic() {
        writeCommand(NobiProtocol.musicStop)
        music.playing = false
    }

    /// Sends a composition; Kairo saves it as "My song" and plays it.
    func playComposition(bpm: Int, notes: [ComposedNote]) {
        guard !notes.isEmpty else { return }
        writeCommand(NobiProtocol.musicCustom(bpm: bpm, notes: notes))
        music.playing = true
    }

    // MARK: - Kairo v0.7: Find my Kairo

    func startFind() {
        writeCommand(NobiProtocol.findStart)
        isFinding = true
    }

    func stopFind() {
        writeCommand(NobiProtocol.findStop)
        isFinding = false
    }

    // MARK: - Mini-games (Spec §32-§39)

    func launchGame(_ game: NobiGame) {
        writeCommand(NobiProtocol.gameLaunch(game.rawValue))
        deviceState.activeGame = game.rawValue
    }

    func stopGame() { writeCommand(NobiProtocol.gameStop) }
    func requestGameScores() { writeCommand(NobiProtocol.gamesScores) }

    // MARK: - Proximity (Spec §9/§29)

    func sendProximity(_ zone: ProximityZone) {
        writeCommand(NobiProtocol.proximity(zone.rawValue))
        deviceState.proximity = zone.rawValue
    }

    // MARK: - Image transfer (dedicated characteristic)

    func beginImageTransfer(bitmap: Data) {
        guard canSendCommand else {
            imageTransferState = .failed("not connected")
            return
        }
        guard bitmap.count == NobiProtocol.imageByteCount else {
            imageTransferState = .failed("bitmap must be 1024 bytes (got \(bitmap.count))")
            return
        }
        guard imageChar != nil else {
            imageTransferState = .failed("image channel missing")
            return
        }
        pendingBitmap = bitmap
        pendingOffset = 0
        awaitingImageReceived = false
        imageTransferState = .waitingBeginAck
        writeCommand(NobiProtocol.imageBegin)
        startImageWatchdog()
    }

    func cancelImageTransfer() {
        abortImageTransfer(reason: "cancelled")
    }

    func resetImageTransferState() {
        if !imageTransferState.isActive { imageTransferState = .idle }
    }

    private func startImageWatchdog() {
        imageWatchdog?.invalidate()
        imageWatchdog = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.imageTransferState.isActive {
                self.log("Image transfer timed out waiting for device")
                self.abortImageTransfer(reason: "timed out — try again")
            }
        }
    }

    private func stopImageWatchdog() {
        imageWatchdog?.invalidate()
        imageWatchdog = nil
    }

    private func abortImageTransfer(reason: String) {
        pendingBitmap = nil
        pendingOffset = 0
        awaitingImageReceived = false
        stopImageWatchdog()
        if imageTransferState.isActive {
            imageTransferState = .failed(reason)
        }
    }

    private func pumpImageQueue() {
        guard let p = peripheral, let c = imageChar, let bitmap = pendingBitmap else { return }
        guard !awaitingImageReceived else { return }
        let chunkSize = max(1, p.maximumWriteValueLength(for: .withoutResponse))
        while pendingOffset < bitmap.count {
            guard p.canSendWriteWithoutResponse else {
                log("Backpressure — waiting (\(pendingOffset)/\(bitmap.count))")
                return
            }
            let end = min(pendingOffset + chunkSize, bitmap.count)
            let chunk = bitmap.subdata(in: pendingOffset..<end)
            p.writeValue(chunk, for: c, type: .withoutResponse)
            pendingOffset = end
            imageTransferState = .sending(progress: Double(pendingOffset) / Double(bitmap.count))
        }
        awaitingImageReceived = true
        imageTransferState = .waitingReceived
        log("All 1024 bytes sent — waiting for image_received")
    }

    // MARK: - Inbound messages

    private func handleTX(_ message: String) {
        log(message, direction: "←")

        if message == "pong" {
            pingResult = "pong ✓"
            return
        }

        if message == "ok:time" {
            deviceState.timeSynced = true
            return
        }

        if message.hasPrefix("status|") {
            let dict = NobiProtocol.parseStatus(message)
            var next = NobiDeviceState(dict: dict, raw: message)
            next.carryScores(from: deviceState)
            deviceState = next
            if profile.lastFirmware != next.firmware { profile.lastFirmware = next.firmware }
            if pendingRestoreCheck {
                pendingRestoreCheck = false
                let hasImage = dict["image"] == "1"
                if fleet?.restoreImageAfterReconnect == true, !hasImage,
                   let bitmap = profile.savedBitmap,
                   bitmap.count == NobiProtocol.imageByteCount {
                    log("Device lost its photo — restoring saved bitmap…")
                    beginImageTransfer(bitmap: bitmap)
                }
            }
            return
        }

        if message.hasPrefix("life|") {
            let dict = NobiProtocol.parseLifeStats(message)
            if let v = dict["mood"], let n = Int(v) { deviceState.mood = n }
            if let v = dict["energy"], let n = Int(v) { deviceState.energy = n }
            if let v = dict["attention"], let n = Int(v) { deviceState.attention = n }
            if let v = dict["bond"], let n = Int(v) { deviceState.bond = n }
            if let v = dict["sleep"], let n = Int(v) { deviceState.sleeping = (n == 1) }
            if let v = dict["proximity"] { deviceState.proximity = v }
            return
        }

        if message.hasPrefix("scores|") {
            let scores = NobiProtocol.parseGameScores(message)
            if let c = scores["catch"] {
                deviceState.highCatch = c
                NobiGame.catchBamboo.recordScore(c)
            }
            if let s = scores["says"] {
                deviceState.highSays = s
                NobiGame.says.recordScore(s)
            }
            if let st = scores["stack"] {
                deviceState.highStack = st
                NobiGame.stack.recordScore(st)
            }
            if let d = scores["dodge"] {
                deviceState.highDodge = d
                NobiGame.dodge.recordScore(d)
            }
            return
        }

        if message.hasPrefix("pomodoro|") {
            if let parsed = NobiProtocol.parsePomodoroStatus(message) {
                deviceState.focusActive = parsed.active
                deviceState.focusRemainingSeconds = parsed.remainingSeconds
            }
            let d = NobiProtocol.parsePipeKeyValue(prefix: "pomodoro", message: message)
            if let v = d["phase"] { focusCycle.isBreak = v == "break" }
            if let v = d["round"], let n = Int(v) { focusCycle.round = n }
            if let v = d["rounds"], let n = Int(v) { focusCycle.rounds = n }
            if let v = d["work"], let n = Int(v) { focusCycle.workMinutes = n }
            if let v = d["break"], let n = Int(v) { focusCycle.breakMinutes = n }
            if let v = d["today"], let n = Int(v) { focusCycle.sessionsToday = n }
            return
        }

        // ---- Kairo v0.7 ----
        if let parsed = NobiProtocol.parseGoals(message) {
            goals = parsed
            return
        }
        if let parsed = NobiProtocol.parseReminders(message) {
            reminders = parsed
            return
        }
        if message == "ok:find" {
            isFinding = true
            return
        }
        if message == "event:found" || message == "ok:find:stop" {
            isFinding = false
            return
        }
        if let parsed = NobiProtocol.parseMusic(message) {
            music = parsed
            return
        }
        if message.hasPrefix("event:music:play:") || message.hasPrefix("ok:music:play:") {
            if let last = message.split(separator: ":").last, let n = Int(last) { music.song = n }
            music.playing = true
            return
        }
        if message == "event:music:stop" || message == "ok:music:stop" {
            music.playing = false
            return
        }
        if message == "ok:hold:on" || message == "ok:hold:off" {
            deviceState.hold = message == "ok:hold:on"
            return
        }
        if message == "ok:invert:on" || message == "ok:invert:off" {
            deviceState.inverted = message == "ok:invert:on"
            return
        }
        if message == "ok:sound:on" || message == "ok:sound:off" {
            if reminders == nil { reminders = KairoReminders() }
            reminders?.sound = message == "ok:sound:on"
            return
        }
        if message.hasPrefix("event:focus_done") || message.hasPrefix("event:break_done") {
            requestPomodoroStatus()
            requestStatus()
            return
        }
        if message.hasPrefix("event:") {
            // goal_done, goals_all_done, reminder, nudge… — goals status follows on its own.
            return
        }

        if message.hasPrefix("ok:text_size:") {
            if let last = message.split(separator: ":").last, let ts = Int(last) {
                deviceState.textSize = ts
            }
            return
        }

        if message.hasPrefix("ok:image_scale:") {
            if let last = message.split(separator: ":").last, let sc = Int(last) {
                deviceState.imageScale = sc
            }
            return
        }

        if message == "ok:life:on" {
            deviceState.lifeModeEnabled = true
            requestLifeStats()
            return
        }
        if message == "ok:life:off" {
            deviceState.lifeModeEnabled = false
            return
        }

        if message == "ok:pet" {
            deviceState.emotion = "love"
            requestLifeStats()
            return
        }

        if message == "ok:sleep" {
            deviceState.sleeping = true
            return
        }
        if message == "ok:wake" {
            deviceState.sleeping = false
            return
        }

        if message.hasPrefix("ok:pomodoro:start") {
            deviceState.focusActive = true
            requestPomodoroStatus()
            return
        }
        if message == "ok:pomodoro:stop" {
            deviceState.focusActive = false
            deviceState.focusRemainingSeconds = 0
            return
        }

        if message.hasPrefix("ok:game:") {
            let gameName = String(message.dropFirst("ok:game:".count))
            if gameName == "stop" {
                deviceState.activeGame = "none"
                requestGameScores()
                requestLifeStats()
            } else {
                deviceState.activeGame = gameName
            }
            return
        }

        // Image handshake
        if message.hasPrefix("ok:image_begin") {
            pumpImageQueue()
            return
        }
        if message.hasPrefix("image_received:") {
            guard pendingBitmap != nil else { return }
            imageTransferState = .finishing
            writeCommand(NobiProtocol.imageEnd)
            return
        }
        if message.hasPrefix("ok:image:") {
            if let bitmap = pendingBitmap {
                profile.savedBitmap = bitmap
            }
            pendingBitmap = nil
            awaitingImageReceived = false
            stopImageWatchdog()
            imageTransferState = .succeeded
            requestStatus()
            return
        }
        if message == "ok:image_show" {
            deviceState.screen = "image"
            return
        }
        if message == "ok:image_clear" {
            deviceState.hasImage = false
            requestStatus()
            return
        }
        if message.hasPrefix("error:image_size") {
            abortImageTransfer(reason: "size mismatch — try again")
            return
        }
        if message == "error:no_image" {
            log("Device has no image in RAM")
            return
        }
        if message == "error:notify_format" {
            log("Note rejected: bad format")
            return
        }
        if message.hasPrefix("error:") {
            log("Device error: \(message)")
            return
        }

        if message.hasPrefix("ok:brightness:") {
            if let last = message.split(separator: ":").last, let b = Int(last) {
                deviceState.brightness = b
            }
            return
        }

        if message.hasPrefix("ok:emotion:") {
            deviceState.emotion = String(message.dropFirst("ok:emotion:".count))
            return
        }
        if message == "ok:face" {
            deviceState.screen = "home"
            return
        }
        if message == "ok:text" {
            deviceState.screen = "text"
            return
        }
        if message == "ok:notify" {
            deviceState.screen = "notification"
            return
        }
    }
}

// MARK: - CBPeripheralDelegate

extension NobiRobot: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            log("Service discovery failed: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services,
              services.contains(where: { $0.uuid == NobiProtocol.service }) else {
            log("Nobi service missing")
            return
        }
        for s in services where s.uuid == NobiProtocol.service {
            peripheral.discoverCharacteristics(
                [NobiProtocol.commandRX, NobiProtocol.tx, NobiProtocol.imageRX], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            log("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        for c in service.characteristics ?? [] {
            switch c.uuid {
            case NobiProtocol.commandRX: commandChar = c
            case NobiProtocol.tx: txChar = c
            case NobiProtocol.imageRX: imageChar = c
            default: break
            }
        }
        guard let tx = txChar, commandChar != nil, imageChar != nil else {
            log("Characteristic missing (cmd=\(commandChar != nil) tx=\(txChar != nil) img=\(imageChar != nil))")
            return
        }
        log("Characteristics ready — subscribing…")
        peripheral.setNotifyValue(true, for: tx)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            log("TX subscribe failed: \(error.localizedDescription)")
            return
        }
        if characteristic.uuid == NobiProtocol.tx, characteristic.isNotifying {
            log("TX subscribed ✓")
            pendingRestoreCheck = fleet?.restoreImageAfterReconnect ?? false
            executePostConnectionHandshake()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            log("Read failed: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == NobiProtocol.tx,
              let data = characteristic.value,
              let message = String(data: data, encoding: .utf8) else { return }
        handleTX(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            log("Write failed (\(characteristic.uuid.uuidString.prefix(8))): \(error.localizedDescription)")
            if characteristic.uuid == NobiProtocol.commandRX, imageTransferState == .waitingBeginAck {
                abortImageTransfer(reason: "image_begin write failed")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error {
            log("RSSI read error: \(error.localizedDescription)")
            return
        }
        rssi = RSSI.intValue
        proximityMonitor.didReadRSSI(RSSI.intValue)
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        pumpImageQueue()
    }
}
