//
//  AudioManager.swift
//  BoomOrBonus
//
//  Created by chang chiawei on 2025-03-30.
//

import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    var player: AVAudioPlayer?

    func playSound(_ name: String, type: String = "mp3") {
        if let path = Bundle.main.path(forResource: name, ofType: type) {
            player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            player?.play()
        }
    }
}
