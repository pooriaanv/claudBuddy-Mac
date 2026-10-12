import AVFoundation
import Foundation

/// How a character's knock sounds.
enum KnockTone: CaseIterable {
    case knuckle   // knuckle on glass
    case paw       // soft, muffled pat
    case metal     // tiny robot clink

    /// (frequency, decay, amplitude) partials plus click strength and overall volume.
    fileprivate var recipe: (partials: [(Double, Double, Double)], click: Double, volume: Float) {
        switch self {
        case .knuckle: return ([(190, 45, 0.5), (1320, 55, 0.22), (2710, 90, 0.1)], 0.45, 0.9)
        case .paw: return ([(150, 55, 0.6), (900, 80, 0.1)], 0.18, 0.75)
        case .metal: return ([(240, 60, 0.25), (1850, 22, 0.25), (2930, 26, 0.16), (4210, 35, 0.08)], 0.35, 0.7)
        }
    }
}

/// Synthesized knock sounds. Players exist only while knocking — idle audio players keep CPU busy.
final class KnockSound {
    private var players: [KnockTone: [AVAudioPlayer]] = [:]
    private var index = 0

    func play(_ tone: KnockTone) {
        if players[tone] == nil {
            let data = Self.wav(tone)
            players[tone] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(data: data)
                p?.volume = tone.recipe.volume
                p?.prepareToPlay()
                return p
            }
        }
        guard let list = players[tone], !list.isEmpty else { return }
        let p = list[index % list.count]
        index += 1
        p.currentTime = 0
        p.play()
    }

    func release() { players.removeAll() }

    static func wav(_ tone: KnockTone) -> Data {
        let sr = 44100.0
        let n = Int(sr * 0.22)
        let r = tone.recipe
        var seed: UInt32 = 12345
        var samples = [Int16]()
        samples.reserveCapacity(n)
        for i in 0..<n {
            let t = Double(i) / sr
            seed = seed &* 1664525 &+ 1013904223
            let noise = Double(Int32(bitPattern: seed)) / Double(Int32.max)
            var v = noise * exp(-t * 400) * r.click
            for (f, d, a) in r.partials { v += sin(2 * .pi * f * t) * exp(-t * d) * a }
            samples.append(Int16(max(-1, min(1, v)) * 30000))
        }
        var d = Data()
        func str(_ s: String) { d.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        str("RIFF"); u32(UInt32(36 + n * 2)); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1); u32(44100); u32(88200); u16(2); u16(16)
        str("data"); u32(UInt32(n * 2))
        samples.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }
}
