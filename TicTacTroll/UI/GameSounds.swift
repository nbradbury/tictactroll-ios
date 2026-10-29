import AVFoundation

/// Game sounds, played by diffing each state against the one before. Against the CPU a Bramble win is the player's
/// loss, so it gets the trombone.
@MainActor
final class GameSounds {
    private let engine = AVAudioEngine()
    /// Round-robin voices; the varispeed unit changes pitch and speed together, like Android's SoundPool rate.
    private var voices: [(player: AVAudioPlayerNode, speed: AVAudioUnitVarispeed)] = []
    private var nextVoice = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    init() {
        let names = ["thunk", "pop", "fanfare", "womp_womp", "tie", "meh_gorp", "bleh_gorp", "meh_bramble", "bleh_bramble"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "caf"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil
            else { continue }
            buffers[name] = buffer
        }
        let format = buffers.values.first?.format
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            let speed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(speed)
            engine.connect(player, to: speed, format: format)
            engine.connect(speed, to: engine.mainMixerNode, format: format)
            voices.append((player, speed))
        }
    }

    func onChange(from previous: GameState, to state: GameState, enabled: Bool) {
        guard enabled else { return }
        playLandings(previous, state)
        playDeparture(previous, state)
        playFallenPops(previous, state)
        playVoices(previous, state)
        playStinger(previous, state)
    }

    private func playLandings(_ previous: GameState, _ state: GameState) {
        for (i, team) in state.board.enumerated() where team != nil && previous.board[i] == nil {
            // Gorp lands a little lighter than Bramble.
            play("thunk", rate: team == .a ? 1.12 : 0.88)
        }
    }

    /// A bubble pop as a bored troll vanishes under rolling rules.
    private func playDeparture(_ previous: GameState, _ state: GameState) {
        guard let departed = state.departed, let team = previous.board[departed], state.board[departed] == nil else {
            return
        }
        // Gorp pops a little higher than Bramble; the sound's own lead-in syncs it with the burst.
        play("pop", rate: team == .a ? 1.1 : 0.9)
    }

    /// A pop as each losing troll bursts after landing in the dirt.
    private func playFallenPops(_ previous: GameState, _ state: GameState) {
        for cell in state.popped.subtracting(previous.popped) {
            if let team = state.board[cell] { play("pop", rate: team == .a ? 1.1 : 0.9) }
        }
    }

    private func playVoices(_ previous: GameState, _ state: GameState) {
        // Once per team and word, so the draw chorus doesn't stack 9 deep.
        var voiced = Set<String>()
        for (key, text) in state.bubbles where previous.bubbles[key] != text {
            guard let team = teamOf(state, key) else { continue }
            let name = "\(text)_\(team == .a ? "gorp" : "bramble")"
            if voiced.insert(name).inserted { play(name) }
        }
    }

    private func playStinger(_ previous: GameState, _ state: GameState) {
        guard previous.result == nil, let result = state.result else { return }
        let stinger = if result.isDraw {
            "tie"
        } else if state.mode == .cpu && result.winner == .b {
            "womp_womp"
        } else {
            "fanfare"
        }
        play(stinger, varyPitch: false)
    }

    private func teamOf(_ state: GameState, _ key: Int) -> Team? {
        switch key {
        case menuA: .a
        case menuB: .b
        default: state.board.indices.contains(key) ? state.board[key] : nil
        }
    }

    /// Plays `name`, by default with a slight random pitch so repeats don't sound canned. Unknown names (like "ooh",
    /// which has no recording) are ignored.
    private func play(_ name: String, rate: Float = 1, varyPitch: Bool = true) {
        guard let buffer = buffers[name] else { return }
        if !engine.isRunning {
            guard (try? engine.start()) != nil else { return }
        }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.speed.rate = rate * (varyPitch ? Float.random(in: 0.95..<1.05) : 1)
        voice.player.stop()
        voice.player.scheduleBuffer(buffer)
        voice.player.play()
    }
}
