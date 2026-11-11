import AVFoundation
import AppKit

/// One sound to loop while the lid moves: built in, or a file from the Sounds folder.
struct Sound: Hashable, Identifiable {
    enum Source: Hashable { case creak, squeak, file(URL) }
    let source: Source

    var id: String {
        switch source {
        case .creak: "creak"
        case .squeak: "squeak"
        case .file(let url): url.lastPathComponent
        }
    }

    var name: String {
        let s = Player.shared.s
        return switch source {
        case .creak: s.creak
        case .squeak: s.squeak
        case .file(let url): url.deletingPathExtension().lastPathComponent
        }
    }

    static let builtIn = [Sound(source: .creak), Sound(source: .squeak)]
}

/// Plays the chosen sound in a loop while the lid moves: loudest when it moves slowly, like
/// a real door, quieter when it is swung fast, a little higher in pitch the faster it goes.
@Observable
final class Player {
    static let shared = Player()

    let s = Strings.for(Strings.detected)

    var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "enabled")
            if !enabled { pause() }
        }
    }

    var volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.8 {
        didSet { UserDefaults.standard.set(volume, forKey: "volume") }
    }

    var soundID = UserDefaults.standard.string(forKey: "sound") ?? "creak" {
        didSet {
            UserDefaults.standard.set(soundID, forKey: "sound")
            load()
        }
    }

    var menuBar = MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: "menuBar") ?? "") ?? .icon {
        didSet { UserDefaults.standard.set(menuBar.rawValue, forKey: "menuBar") }
    }

    private(set) var sounds = Sound.builtIn

    /// ~/Library/Application Support/Lid Sound/Sounds: every audio file in it is a sound.
    static let folder = URL.applicationSupportDirectory.appending(path: "Lid Sound/Sounds")
    private static let types: Set = ["wav", "aif", "aiff", "aifc", "caf", "m4a", "mp3", "flac"]

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let node = AVAudioPlayerNode()
    @ObservationIgnored private let varispeed = AVAudioUnitVarispeed()
    @ObservationIgnored private var buffer: AVAudioPCMBuffer?
    @ObservationIgnored private var gain = 0.0
    @ObservationIgnored private var rate = 1.0
    @ObservationIgnored private var quietSince: TimeInterval?
    @ObservationIgnored private var lastUpdate: TimeInterval?

    func start() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        engine.attach(node)
        engine.attach(varispeed)
        rescan()
        load()
    }

    /// Looks in the Sounds folder again; called whenever the panel opens.
    func rescan() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let found = files
            .filter { Self.types.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { Sound(source: .file($0)) }
        sounds = Sound.builtIn + found
        // A file taken out of the folder leaves the built-in creak in its place.
        if !sounds.contains(where: { $0.id == soundID }) { soundID = "creak" }
    }

    func openFolder() {
        NSWorkspace.shared.open(Self.folder)
    }

    private func load() {
        guard let sound = sounds.first(where: { $0.id == soundID }) else { return }
        let next: AVAudioPCMBuffer? = switch sound.source {
        case .creak: Synth.creak()
        case .squeak: Synth.squeak()
        case .file(let url): Self.read(url)
        }
        guard let next else { return }
        engine.stop()
        node.stop()
        engine.disconnectNodeOutput(node)
        engine.disconnectNodeOutput(varispeed)
        engine.connect(node, to: varispeed, format: next.format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: next.format)
        buffer = next
        gain = 0
        node.volume = 0
    }

    private static func read(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, buffer.frameLength > 0 else { return nil }
        return buffer
    }

    /// Called with the lid's speed 60 times a second.
    func update(velocity: Double) {
        guard enabled, buffer != nil else { return }
        let speed = abs(velocity)
        // Silent below a degree a second (the sensor's own jitter), full at 10, fading out
        // towards 100: a door swung fast barely creaks.
        var target = 0.0
        if speed >= 1 {
            let t = min(1, max(0, (speed - 10) / 90))
            target = 1 - t * t * (3 - 2 * t)
        }
        // Readings come 60 times a second while the lid moves, 10 while it rests.
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - (lastUpdate ?? now - 1.0 / 60))
        lastUpdate = now
        gain += (target - gain) * (1 - exp(-dt / 0.05))
        rate += (0.8 + 0.3 * min(1, speed / 100) - rate) * (1 - exp(-dt / 0.08))

        // The audio engine sleeps while the lid is still, so the app costs nothing at rest.
        if target > 0 {
            quietSince = nil
            resume()
        } else if gain < 0.001 {
            if quietSince == nil { quietSince = now }
            if let q = quietSince, now - q > 1 { pause() }
        }
        node.volume = Float(gain * volume)
        varispeed.rate = Float(rate)
    }

    private func resume() {
        guard !engine.isRunning, let buffer else { return }
        do { try engine.start() } catch { return }
        if !node.isPlaying {
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            node.play()
        }
    }

    private func pause() {
        guard engine.isRunning else { return }
        engine.pause()
        gain = 0
        node.volume = 0
    }
}
