import Foundation
import IOKit.hid

/// The lid angle sensor. Apple doesn't document it: it is an HID device on MacBooks from the
/// 16-inch 2019 MacBook Pro and the M2 MacBook Air on, found by Sam Henri Gold
/// (github.com/samhenrigold/LidAngleSensor). Feature report 1 holds the angle in whole
/// degrees, low byte first, in bytes 1 and 2.
@Observable
final class Sensor {
    static let shared = Sensor()

    /// Degrees between the keyboard and the screen; nil without a sensor.
    private(set) var angle: Int?
    /// Degrees per second, without a sign, measured the way LidAngleSensor measures it (see
    /// `read`); it falls away within a few readings once the lid stops.
    @ObservationIgnored private(set) var velocity = 0.0
    /// The same, rounded, for the panel; only a change wakes it.
    private(set) var speed = 0
    /// Whether the lid is moving, from the sensor's own whole-degree steps rather than the
    /// smoothed speed, which lags the lid by up to a second (see `Motion`).
    var moving: Bool { motion.moving }
    @ObservationIgnored private var motion = Motion()
    @ObservationIgnored private var lastRaw: Int?
    @ObservationIgnored private var rawSince: TimeInterval = 0

    @ObservationIgnored private var manager: IOHIDManager?
    @ObservationIgnored private var device: IOHIDDevice?

    /// Counts every degree the lid moves while it moves, so a listener can tell a new step
    /// from a repeat.
    @ObservationIgnored private(set) var steps = 0

    // LidAngleSensor's measuring state and constants, unchanged.
    @ObservationIgnored private var smoothedAngle: Double?
    @ObservationIgnored private var lastAngle = 0.0
    @ObservationIgnored private var lastUpdate: TimeInterval = 0
    @ObservationIgnored private var lastMovement: TimeInterval = 0
    private static let angleSmoothing = 0.05
    private static let velocitySmoothing = 0.3
    private static let movementThreshold = 0.5
    private static let movementTimeout: TimeInterval = 0.05
    private static let velocityDecay = 0.5
    private static let additionalDecay = 0.8

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var onTick: ((Double) -> Void)?

    @ObservationIgnored private var lastTry: TimeInterval = -10
    @ObservationIgnored private var failures = 0

    /// Reads 30 times a second, as LidAngleSensor does; its smoothing is tuned to that pace.
    /// The sensor can be missing for a moment, at login or after sleep, and can stop
    /// answering; it is looked for again every two seconds until it answers.
    func start(onTick: @escaping (Double) -> Void) {
        self.onTick = onTick
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { _ in
            MainActor.assumeIsolated { Sensor.shared.tick() }
        }
        timer.tolerance = 0.003
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if device == nil {
            guard now - lastTry >= 2 else { return }
            lastTry = now
            open()
            guard device != nil else { return }
        }
        read()
        onTick?(velocity)
    }

    private func open() {
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Int] = [
            kIOHIDVendorIDKey: 0x05AC, kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x20, kIOHIDPrimaryUsageKey: 0x8A,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        let devices = (IOHIDManagerCopyDevices(manager) as NSSet?)?.allObjects ?? []
        // Some Macs list the device without answering; take the first one that gives an angle.
        for case let d as IOHIDDevice in devices where Self.report(d) != nil {
            device = d
            angle = Self.report(d)
            break
        }
    }

    private func read() {
        guard let device else { return }
        guard let a = Self.report(device) else {
            // A second without an answer: let it go and look for it again.
            failures += 1
            if failures >= 30 { self.device = nil; failures = 0 }
            return
        }
        failures = 0
        let now = ProcessInfo.processInfo.systemUptime
        motion.read(a, at: now)
        steps = motion.steps
        // A lid resting right between two degrees reads one, then the other. The angle shown
        // moves at once by two or more, or to a reading that has held for 0.3 s.
        if a != lastRaw { lastRaw = a; rawSince = now }
        if angle == nil || abs(a - (angle ?? a)) >= 2 || (a != angle && now - rawSince >= 0.3) || motion.moving {
            if angle != a { angle = a }
        }
        measure(Double(a), now: now)
        let rounded = Int(velocity.rounded())
        if speed != rounded { speed = rounded }
    }

    /// LidAngleSensor's velocity: the angle is smoothed hard, a change of less than half a
    /// degree counts as none, a real change is blended into the speed, and without one the
    /// speed halves each reading, and more after a twentieth of a second without movement.
    private func measure(_ raw: Double, now: TimeInterval) {
        guard let smoothed = smoothedAngle else {
            smoothedAngle = raw
            lastAngle = raw
            lastUpdate = now
            lastMovement = now
            return
        }
        let dt = now - lastUpdate
        guard dt > 0, dt < 1 else {
            lastUpdate = now
            return
        }
        let angle = Self.angleSmoothing * raw + (1 - Self.angleSmoothing) * smoothed
        smoothedAngle = angle
        let delta = angle - lastAngle
        var instant = 0.0
        if abs(delta) >= Self.movementThreshold {
            instant = abs(delta / dt)
            lastAngle = angle
        }
        if instant > 0 {
            velocity = Self.velocitySmoothing * instant + (1 - Self.velocitySmoothing) * velocity
            lastMovement = now
        } else {
            velocity *= Self.velocityDecay
        }
        if now - lastMovement > Self.movementTimeout {
            velocity *= Self.additionalDecay
        }
        lastUpdate = now
    }

    private static func report(_ device: IOHIDDevice) -> Int? {
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = bytes.count
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &length) == kIOReturnSuccess,
              length >= 3 else { return nil }
        return Int(bytes[2]) << 8 | Int(bytes[1])
    }
}

/// When the lid starts and stops, from the sensor's raw steps. A lid at rest gives the same
/// whole degree reading after reading, or, resting right between two, flicks between them;
/// so a lid at rest starts moving only once it is two degrees from where it stopped. Then
/// every step counts. It has stopped when no step came for 1.6 times the last gap between
/// steps: a lid swung fast steps every reading and stops after 0.15 s, a slow one steps every
/// few tenths and gets as long, up to 0.8 s. The first step after a rest has no gap yet and
/// gets 0.5 s.
struct Motion {
    private(set) var moving = false
    /// Every degree stepped while moving.
    private(set) var steps = 0
    private var rest: Int?
    private var last: Int?
    private var lastStep: TimeInterval = 0
    private var gap: TimeInterval?

    mutating func read(_ angle: Int, at now: TimeInterval) {
        defer { check(at: now) }
        guard let previous = last else {
            last = angle; rest = angle; return
        }
        guard angle != previous else { return }
        last = angle
        if moving || abs(angle - (rest ?? angle)) >= 2 {
            steps += abs(angle - previous)
            gap = moving ? now - lastStep : nil
            lastStep = now
            moving = true
        }
    }

    private mutating func check(at now: TimeInterval) {
        let wait = gap.map { min(0.8, max(0.15, 1.6 * $0)) } ?? 0.5
        if moving, now - lastStep > wait {
            moving = false
            rest = last
        }
    }
}
