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
    /// Degrees per second, smoothed; positive while opening.
    @ObservationIgnored private(set) var velocity = 0.0

    @ObservationIgnored private var manager: IOHIDManager?
    @ObservationIgnored private var device: IOHIDDevice?
    @ObservationIgnored private var last: (angle: Double, time: TimeInterval)?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var onTick: ((Double) -> Void)?
    @ObservationIgnored private var stillSince: TimeInterval?

    /// Reads 60 times a second while the lid moves, as fast as it can be seen to move, and
    /// 10 times a second while it rests, which is enough to catch it starting to move.
    func start(onTick: @escaping (Double) -> Void) {
        open()
        guard device != nil else { return }
        self.onTick = onTick
        schedule(every: 1.0 / 10)
    }

    private func schedule(every interval: TimeInterval) {
        guard timer?.timeInterval != interval else { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { Sensor.shared.tick() }
        }
        timer.tolerance = interval / 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        read()
        onTick?(velocity)
        let now = ProcessInfo.processInfo.systemUptime
        if abs(velocity) >= 0.5 {
            stillSince = nil
            schedule(every: 1.0 / 60)
        } else {
            if stillSince == nil { stillSince = now }
            if let still = stillSince, now - still > 1.5 { schedule(every: 1.0 / 10) }
        }
    }

    private func open() {
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
        guard let device, let a = Self.report(device) else { return }
        // Only a real change wakes the panel, not every reading.
        if angle != a { angle = a }
        let now = ProcessInfo.processInfo.systemUptime
        defer { last = (Double(a), now) }
        guard let last, now > last.time else { return }
        // The angle comes in whole degrees, so a slow lid steps once every few readings; the
        // smoothing (about a tenth of a second) turns those steps into a steady speed.
        let dt = now - last.time
        let v = (Double(a) - last.angle) / dt
        velocity += (v - velocity) * (1 - exp(-dt / 0.1))
    }

    private static func report(_ device: IOHIDDevice) -> Int? {
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = bytes.count
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &length) == kIOReturnSuccess,
              length >= 3 else { return nil }
        return Int(bytes[2]) << 8 | Int(bytes[1])
    }
}
