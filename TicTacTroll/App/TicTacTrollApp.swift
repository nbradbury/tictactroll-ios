import AVFoundation
import SwiftUI

private let keySound = "sound_on"
private let keyBoredTrolls = "bored_trolls"

@main
struct TicTacTrollApp: App {
    // Created with the saved rules so the switch starts in place instead of animating on at launch.
    @State private var model = GameModel(rules: UserDefaults.standard.bool(forKey: keyBoredTrolls) ? .rolling : .classic)
    // Held here rather than in a view, so they're created once.
    @State private var sounds = GameSounds()
    @State private var haptics = GameHaptics()
    @State private var music = BackgroundMusic(resource: "where_the_trolls_tread")

    init() {
        Font.registerAppFonts()
        // Ambient: respects the silent switch and mixes with whatever else is playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, sounds: sounds, haptics: haptics, music: music)
        }
    }
}

private struct RootView: View {
    let model: GameModel
    let sounds: GameSounds
    let haptics: GameHaptics
    let music: BackgroundMusic

    @AppStorage(keySound) private var soundOn = true
    @AppStorage(keyBoredTrolls) private var boredTrolls = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Backdrop().ignoresSafeArea()
            FitToWindow {
                switch model.state.screen {
                case .menu: MenuView(model: model, soundOn: $soundOn, boredTrolls: $boredTrolls)
                case .game: GameView(model: model)
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onChange(of: model.state) { previous, state in
            sounds.onChange(from: previous, to: state, enabled: soundOn)
            haptics.onChange(from: previous, to: state)
        }
        .onChange(of: boredTrolls) { model.setRules(boredTrolls ? .rolling : .classic) }
        .onChange(of: soundOn, initial: true) { updateMusic() }
        .onChange(of: scenePhase) { updateMusic() }
    }

    private func updateMusic() {
        music.update(playing: soundOn && scenePhase == .active)
    }
}
