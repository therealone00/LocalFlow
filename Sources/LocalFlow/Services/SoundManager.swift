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
    
    public func playSuccessSound() {
        guard SettingsManager.shared.settings.soundEffectsEnabled else { return }
        // Subtle minimal feedback
    }
    
    public func playErrorSound() {
        guard SettingsManager.shared.settings.soundEffectsEnabled else { return }
        NSSound(named: "Basso")?.play()
    }
}
