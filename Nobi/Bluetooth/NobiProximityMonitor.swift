import CoreBluetooth
import Foundation

/// Manages conservative RSSI sampling, exponential smoothing, and hysteresis
/// to classify proximity zones (near, mid, far) and report transitions (Spec §9/§29).
final class NobiProximityMonitor {

    // MARK: - Configuration

    /// Thresholds in dBm (tweakable)
    var nearThreshold: Double = -58.0
    var farThreshold: Double = -75.0

    /// Smoothing alpha: 0.75 * old + 0.25 * new
    private let alpha: Double = 0.25

    /// Consecutive readings needed to confirm a zone switch
    private let requiredConsecutiveSamples: Int = 3

    // MARK: - State

    private(set) var currentZone: ProximityZone = .unknown
    private(set) var smoothedRSSI: Double?

    private var candidateZone: ProximityZone = .unknown
    private var candidateCount: Int = 0

    private weak var peripheral: CBPeripheral?
    private var sampleTimer: Timer?
    private var onZoneChanged: ((ProximityZone) -> Void)?

    // MARK: - Lifecycle

    init() {}

    func start(peripheral: CBPeripheral, onZoneChanged: @escaping (ProximityZone) -> Void) {
        self.peripheral = peripheral
        self.onZoneChanged = onZoneChanged
        self.smoothedRSSI = nil
        self.currentZone = .unknown
        self.candidateZone = .unknown
        self.candidateCount = 0

        stop()
        // Conservative cadence: read every 3 seconds while active
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, let p = self.peripheral, p.state == .connected else { return }
            p.readRSSI()
        }
        // Immediate first read
        peripheral.readRSSI()
    }

    func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        peripheral = nil
    }

    // MARK: - Processing RSSI

    func didReadRSSI(_ rawRSSI: Int) {
        let raw = Double(rawRSSI)
        let smoothed: Double
        if let old = smoothedRSSI {
            smoothed = (1.0 - alpha) * old + alpha * raw
        } else {
            smoothed = raw
        }
        self.smoothedRSSI = smoothed

        // Classify instant zone
        let sampleZone: ProximityZone
        if smoothed >= nearThreshold {
            sampleZone = .near
        } else if smoothed >= farThreshold {
            sampleZone = .mid
        } else {
            sampleZone = .far
        }

        // Apply hysteresis
        if sampleZone == currentZone {
            candidateZone = currentZone
            candidateCount = 0
            return
        }

        if sampleZone == candidateZone {
            candidateCount += 1
            if candidateCount >= requiredConsecutiveSamples {
                currentZone = candidateZone
                candidateCount = 0
                onZoneChanged?(currentZone)
            }
        } else {
            candidateZone = sampleZone
            candidateCount = 1
        }
    }
}
