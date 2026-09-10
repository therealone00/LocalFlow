import Foundation
import AppKit

@MainActor
public final class SoundManager {
    public static let shared = SoundManager()
    
    public init() {}
    
    public func playStartSound() {
        guard SettingsManager.shared.settings.soundEffectsEnabled else { return }
        NSSound(named: "Tink")?.play()
    }
    
    public func playStopSound() {
        guard SettingsManager.shared.settings.soundEffectsEnabled else { return }
        NSSound(named: "Pop")?.play()
    }
    
    /// Played once the text has actually landed in the target app. Quieter than
    /// the start/stop tones so a fast dictation does not sound like three beeps.
    public func playSuccessSound() {
        guard SettingsManager.shared.settings.soundEffectsEnabled else { return }
        guard let sound = NSSound(named: "Morse") else { return }
        sound.volume = 0.35
        sound.play()
    }
    
    public func playErrorSound() {
        guard SettingsManager.shared.settings.soundEffectsEnabled else { return }
        NSSound(named: "Basso")?.play()
    }
}
