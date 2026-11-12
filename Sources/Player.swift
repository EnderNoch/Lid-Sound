import AVFoundation
import AppKit

/// One sound to play while the lid moves: built in, a file from the Sounds folder, or a pack
/// from it.
struct Sound: Hashable, Identifiable {
    enum Source: Hashable { case creak, squeak, file(URL), pack(URL) }
    let source: Source

    var id: String {
        switch source {
        case .creak: "creak"
        case .squeak: "squeak"
        case .file(let url), .pack(let url): url.lastPathComponent
        }
    }

    var name: String {
        let s = Player.shared.s
        return switch source {
        case .creak: s.creak
        case .squeak: s.squeak
        case .file(let url), .pack(let url): url.deletingPathExtension().lastPathComponent
        }
    }

    static let builtIn = [Sound(source: .creak), Sound(source: .squeak)]
}

/// Plays the chosen sound while the lid moves: loudest when it moves slowly, like a real door,
/// quieter when it is swung fast. A single file loops. A pack is a folder ending in .lidsound
/// with three files, like a recording of a door cut in three: the start plays as the lid
/// starts to move, the middle while it moves, the end when it stops.
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

    /// A pack's middle in steps instead of a loop: its first film frame (a 24th of a second)
    /// played once for every degree the lid moves, like the clicks of a hinge. Kept for each
    /// pack.
    var step = false {
        didSet {
            guard isPack else { return }
            var all = UserDefaults.standard.dictionary(forKey: "step") ?? [:]
            all[soundID] = step
            UserDefaults.standard.set(all, forKey: "step")
            stopAll()
        }
    }

    private(set) var sounds = Sound.builtIn
    /// Whether the chosen sound is a pack, with a start, a middle and an end.
    private(set) var isPack = false
    /// The chosen pack's parts' lengths in seconds; nil for a part it doesn't have.
    private(set) var lengths: [Part: Double] = [:]

    /// ~/Library/Application Support/Lid Sound/Sounds: every audio file in it is a sound, and
    /// every folder ending in .lidsound a pack.
    static let folder = URL.applicationSupportDirectory.appending(path: "Lid Sound/Sounds")
    private static let types: Set = ["wav", "aif", "aiff", "aifc", "caf", "m4a", "mp3", "flac"]
    /// What a folder's name ends in to be a pack: a plain folder, so it opens and fills like
    /// any other, but the app knows it from the rest.
    static let packExtension = "lidsound"
    /// A pack's files, by name without the extension: English or Polish.
    private static let names: [Part: Set<String>] = [
        .start: ["start", "początek"], .middle: ["middle", "środek"], .end: ["end", "koniec"],
    ]
    /// How long a step is: one frame of film.
    static let tick = 1.0 / 24

    enum Part { case start, middle, end }
    private enum Phase { case idle, playing, ending }

    @ObservationIgnored private let engine = AVAudioEngine()
    /// Plays the start and the middle, through the varispeed.
    @ObservationIgnored private let node = AVAudioPlayerNode()
    /// Plays the end, so the middle can fade out under it instead of being cut off.
    @ObservationIgnored private let tail = AVAudioPlayerNode()
    /// Play the ticks in turn, so each one rings out under the next instead of being cut off.
    @ObservationIgnored private let voices = (0..<6).map { _ in AVAudioPlayerNode() }
    @ObservationIgnored private var nextVoice = 0
    @ObservationIgnored private let varispeed = AVAudioUnitVarispeed()
    @ObservationIgnored private var head: AVAudioPCMBuffer?
    @ObservationIgnored private var loop: AVAudioPCMBuffer?
    @ObservationIgnored private var end: AVAudioPCMBuffer?
    /// The middle's first film frame, its edges faded over three milliseconds, to play
    /// without a click.
    @ObservationIgnored private var tick: AVAudioPCMBuffer?
    @ObservationIgnored private var ticksFrom: TimeInterval = 0
    @ObservationIgnored private var lastSteps = 0
    @ObservationIgnored private var phase = Phase.idle
    @ObservationIgnored private var gain = 0.0
    @ObservationIgnored private var peak = 0.0
    @ObservationIgnored private var rate = 1.0
    @ObservationIgnored private var lastMotion: TimeInterval = 0
    @ObservationIgnored private var endsAt: TimeInterval = 0
    @ObservationIgnored private var lastUpdate: TimeInterval?

    private var split: Bool { head != nil || end != nil || (step && tick != nil) }

    func start() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        engine.attach(node)
        engine.attach(tail)
        engine.attach(varispeed)
        voices.forEach(engine.attach)
        rescan()
        load()
    }

    /// Looks in the Sounds folder again; called whenever the panel opens.
    func rescan() {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: Self.folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let found = items
            .compactMap { url -> Sound? in
                let ext = url.pathExtension.lowercased()
                if ext == Self.packExtension, url.hasDirectoryPath { return Sound(source: .pack(url)) }
                return Self.types.contains(ext) ? Sound(source: .file(url)) : nil
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        sounds = Sound.builtIn + found
        // A sound taken out of the folder leaves the built-in creak in its place.
        if !sounds.contains(where: { $0.id == soundID }) { soundID = "creak" }
    }

    func openFolder() {
        NSWorkspace.shared.open(Self.folder)
    }

    private func load() {
        guard let sound = sounds.first(where: { $0.id == soundID }) else { return }
        var parts: [Part: AVAudioPCMBuffer] = [:]
        switch sound.source {
        case .creak: parts[.middle] = Synth.creak()
        case .squeak: parts[.middle] = Synth.squeak()
        case .file(let url): parts[.middle] = Self.read(url)
        case .pack(let url): parts = Self.readPack(url)
        }
        // Any part will do; a pack of only a start and an end is a door that knocks as it
        // starts and as it stops, with nothing in between.
        guard let first = parts[.middle] ?? parts[.start] ?? parts[.end] else { return }
        let format = first.format
        engine.stop()
        stopAll()
        engine.disconnectNodeOutput(node)
        engine.disconnectNodeOutput(tail)
        engine.disconnectNodeOutput(varispeed)
        for v in voices {
            engine.disconnectNodeOutput(v)
            engine.connect(v, to: engine.mainMixerNode, format: format)
        }
        engine.connect(node, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        engine.connect(tail, to: engine.mainMixerNode, format: format)
        // All three play through the same nodes, so they take on one format, the middle's if
        // there is one.
        head = parts[.start].flatMap { Self.convert($0, to: format) }
        loop = parts[.middle]
        end = parts[.end].flatMap { Self.convert($0, to: format) }
        tick = loop.flatMap { Self.slice($0, 0, min(Int($0.frameLength), Int(format.sampleRate * Self.tick))) }.map(Self.faded)
        lengths = [.start: head, .middle: loop, .end: end].compactMapValues { b in
            b.map { Double($0.frameLength) / $0.format.sampleRate }
        }
        if case .pack = sound.source { isPack = true } else { isPack = false }
        step = isPack && (UserDefaults.standard.dictionary(forKey: "step")?[soundID] as? Bool ?? false)
        gain = 0
        node.volume = 0
    }

    /// The pack's files by part; names are matched without case and without the extension.
    private static func readPack(_ url: URL) -> [Part: AVAudioPCMBuffer] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        var parts: [Part: AVAudioPCMBuffer] = [:]
        for file in files where types.contains(file.pathExtension.lowercased()) {
            let name = file.deletingPathExtension().lastPathComponent.lowercased()
            guard let part = names.first(where: { $0.value.contains(name) })?.key else { continue }
            parts[part] = read(file)
        }
        return parts
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }
        let count = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { return nil }
        var given = false
        let status = converter.convert(to: out, error: nil) { _, state in
            if given {
                state.pointee = .endOfStream
                return nil
            }
            given = true
            state.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : out
    }

    private func stopAll() {
        node.stop()
        tail.stop()
        voices.forEach { $0.stop() }
        phase = .idle
    }

    private static func slice(_ buffer: AVAudioPCMBuffer, _ from: Int, _ to: Int) -> AVAudioPCMBuffer? {
        let count = to - from
        guard count > 0, let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(count)),
              let source = buffer.floatChannelData, let target = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(count)
        for c in 0..<Int(buffer.format.channelCount) {
            target[c].update(from: source[c] + from, count: count)
        }
        return out
    }

    private static func faded(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let n = Int(buffer.frameLength)
        let edge = min(n / 2, Int(buffer.format.sampleRate * 0.003))
        guard edge > 0, let data = buffer.floatChannelData else { return buffer }
        for c in 0..<Int(buffer.format.channelCount) {
            for i in 0..<edge {
                let k = Float(i) / Float(edge)
                data[c][i] *= k
                data[c][n - 1 - i] *= k
            }
        }
        return buffer
    }

    private static func read(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, buffer.frameLength > 0 else { return nil }
        return buffer
    }

    /// Called with the lid's speed 60 times a second while it moves, 10 while it rests.
    func update(velocity: Double) {
        guard enabled, loop != nil || split else { return }
        let speed = abs(velocity)
        // Silent while the lid rests, full up to 10 degrees a second, fading out towards 100:
        // a door swung fast barely creaks.
        let sensor = Sensor.shared
        var target = 0.0
        if sensor.moving {
            let t = min(1, max(0, (speed - 10) / 90))
            target = 1 - t * t * (3 - 2 * t)
        }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - (lastUpdate ?? now - 1.0 / 60))
        lastUpdate = now
        let stepped = sensor.steps != lastSteps
        lastSteps = sensor.steps
        if target > 0 || stepped { lastMotion = now }

        if split {
            let t = min(1, max(0, (speed - 10) / 90))
            playParts(loudness: 1 - t * t * (3 - 2 * t), stepped: stepped,
                      stopped: !sensor.moving, now: now, dt: dt)
        } else {
            gain += (target - gain) * (1 - exp(-dt / 0.05))
            rate += (0.8 + 0.3 * min(1, speed / 100) - rate) * (1 - exp(-dt / 0.08))
            if target > 0 { resume() }
            varispeed.rate = Float(rate)
        }
        node.volume = Float(gain * volume)

        // The audio engine sleeps while the lid is still, so the app costs nothing at rest.
        if phase != .playing, now - lastMotion > 1, now > endsAt + 0.2 { pause() }
    }

    /// Start, middle and end, at the recording's own pitch.
    private func playParts(loudness: Double, stepped: Bool, stopped: Bool, now: TimeInterval, dt: Double) {
        varispeed.rate = 1
        switch phase {
        case .idle, .ending:
            if !stopped { begin(loudness: loudness, now: now) }
            if phase == .ending {
                // The middle fades out in a few hundredths of a second as the end comes in.
                gain += (0 - gain) * (1 - exp(-dt / 0.03))
                if gain < 0.001 { node.stop() }
            }
        case .playing:
            if stopped {
                finish(now: now)
            } else {
                gain += (loudness - gain) * (1 - exp(-dt / 0.05))
                peak = max(peak, gain)
                // A tick for each step, once the start has played.
                if step, stepped, now >= ticksFrom { playTick() }
            }
        }
    }

    private func begin(loudness: Double, now: TimeInterval) {
        guard startEngine() else { return }
        node.stop()
        if let head { node.scheduleBuffer(head, at: nil) }
        if step {
            ticksFrom = now + (head.map { Double($0.frameLength) / $0.format.sampleRate } ?? 0)
        } else if let loop {
            node.scheduleBuffer(loop, at: nil, options: .loops)
        }
        // The start comes in at once, not faded in, so the first crack of the creak is heard.
        gain = loudness
        peak = loudness
        node.volume = Float(gain * volume)
        node.play()
        phase = .playing
        if step, head == nil { playTick() }
    }

    private func playTick() {
        guard let tick else { return }
        let f = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        f.stop()
        f.volume = Float(gain * volume)
        f.scheduleBuffer(tick, at: nil)
        f.play()
    }

    private func finish(now: TimeInterval) {
        phase = .ending
        endsAt = now
        guard let end else { return }
        tail.stop()
        tail.volume = Float(peak * volume)
        tail.scheduleBuffer(end, at: nil)
        tail.play()
        endsAt = now + Double(end.frameLength) / end.format.sampleRate
    }

    /// Plays one part once at the chosen volume, to hear where the lines are.
    func preview(_ part: Part) {
        let buffer = switch part {
        case .start: head
        case .middle: step ? tick : loop
        case .end: end
        }
        guard let buffer, startEngine() else { return }
        tail.stop()
        tail.volume = Float(volume)
        tail.scheduleBuffer(buffer, at: nil)
        tail.play()
        // Keeps the engine awake until the part has played.
        endsAt = ProcessInfo.processInfo.systemUptime + Double(buffer.frameLength) / buffer.format.sampleRate
    }

    private func startEngine() -> Bool {
        if engine.isRunning { return true }
        do { try engine.start() } catch { return false }
        return true
    }

    private func resume() {
        guard let loop, startEngine(), !node.isPlaying else { return }
        node.scheduleBuffer(loop, at: nil, options: .loops)
        node.play()
    }

    private func pause() {
        guard engine.isRunning else { return }
        node.stop()
        tail.stop()
        voices.forEach { $0.stop() }
        engine.pause()
        phase = .idle
        gain = 0
        node.volume = 0
    }
}
