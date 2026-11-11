import AVFoundation

/// The two built-in sounds, made from numbers when the app starts: no recordings, so nothing
/// borrowed from a game or a sound library. Each one is a loop that joins up without a click.
enum Synth {
    static let rate = 48_000.0
    static let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!

    /// A wooden door: a slow string of knocks (the hinge sticking and slipping) ringing through
    /// three wood resonances, over a little rustle.
    static func creak() -> AVAudioPCMBuffer {
        let length = 3.0
        var rng = Random(seed: 11)
        let wander = Curve(length: length, terms: 5, rng: &rng)
        let swell = Curve(length: length, terms: 3, rng: &rng)
        // Rendered with a tail past the loop's end, so the resonances ring on into the start.
        let total = Int((length + 0.3) * rate)
        var knocks = [Double](repeating: 0, count: total)
        var phase = 0.0
        for i in 0..<total {
            let t = Double(i) / rate
            phase += (70 + 45 * tanh(1.5 * wander(t))) / rate
            if phase >= 1 {
                phase -= 1
                knocks[i] = (0.5 + 0.5 * rng.next()) * max(0.1, min(1, 0.6 + 0.7 * swell(t)))
            }
            knocks[i] += 0.015 * (rng.next() * 2 - 1)
        }
        var out = [Double](repeating: 0, count: total)
        for (freq, width, gain) in [(340.0, 60.0, 1.0), (780.0, 110.0, 0.8), (1_620.0, 220.0, 0.45)] {
            var r = Resonator(freq: freq, width: width)
            for i in 0..<total { out[i] += gain * r.step(knocks[i]) }
        }
        return loop(out, length: length)
    }

    /// A dry metal hinge: a squealing tone that wanders in pitch, chattering about 40 times
    /// a second as the hinge catches, rising and falling in waves.
    static func squeak() -> AVAudioPCMBuffer {
        let length = 2.0
        var rng = Random(seed: 7)
        let wander = Curve(length: length, terms: 6, rng: &rng)
        let swell = Curve(length: length, terms: 4, rng: &rng)
        let total = Int(length * rate)
        var freqs = (0..<total).map { 950 + 250 * tanh(wander(Double($0) / rate)) }
        // Whole cycles over the loop, so the tone runs straight on from its end into its start.
        let cycles = freqs.reduce(0, +) / rate
        let fix = cycles.rounded() / cycles
        freqs = freqs.map { $0 * fix }
        var out = [Double](repeating: 0, count: total)
        var phase = 0.0
        for i in 0..<total {
            let t = Double(i) / rate
            phase += 2 * .pi * freqs[i] / rate
            var tone = 0.0
            for h in 1...6 { tone += sin(Double(h) * phase) / pow(Double(h), 1.3) }
            let chatter = 0.55 + 0.45 * pow(sin(2 * .pi * 40 * t), 2)
            out[i] = tone * chatter * max(0.15, min(1, 0.6 + 0.6 * swell(t)))
        }
        return loop(out, length: length)
    }

    /// Folds whatever runs past `length` back over the start, scales to a safe level and
    /// hands the samples over as a buffer.
    private static func loop(_ samples: [Double], length: Double) -> AVAudioPCMBuffer {
        let n = Int(length * rate)
        var s = Array(samples.prefix(n))
        for i in n..<samples.count { s[i - n] += samples[i] }
        let peak = s.map(abs).max() ?? 1
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buffer.frameLength = AVAudioFrameCount(n)
        let data = buffer.floatChannelData![0]
        for i in 0..<n { data[i] = Float(0.8 * s[i] / peak) }
        return buffer
    }
}

/// A smooth random wave that repeats exactly every `length` seconds, so whatever it steers
/// joins up at the loop point.
private struct Curve {
    private let terms: [(cos: Double, sin: Double)]
    private let length: Double

    init(length: Double, terms count: Int, rng: inout Random) {
        self.length = length
        terms = (1...count).map { k in
            ((rng.next() * 2 - 1) / Double(k), (rng.next() * 2 - 1) / Double(k))
        }
    }

    func callAsFunction(_ t: Double) -> Double {
        var v = 0.0
        for (k, c) in terms.enumerated() {
            let w = 2 * .pi * Double(k + 1) * t / length
            v += c.cos * cos(w) + c.sin * sin(w)
        }
        return v
    }
}

/// A two-pole filter that rings at one frequency, like a panel of wood struck once.
private struct Resonator {
    private let a1: Double, a2: Double, gain: Double
    private var y1 = 0.0, y2 = 0.0

    init(freq: Double, width: Double) {
        let r = exp(-.pi * width / Synth.rate)
        a1 = 2 * r * cos(2 * .pi * freq / Synth.rate)
        a2 = -r * r
        gain = 1 - r
    }

    mutating func step(_ x: Double) -> Double {
        let y = gain * x + a1 * y1 + a2 * y2
        y2 = y1
        y1 = y
        return y
    }
}

/// The same numbers on every launch, so the built-in sounds never change.
private struct Random {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    /// SplitMix64, scaled to 0..<1.
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}
