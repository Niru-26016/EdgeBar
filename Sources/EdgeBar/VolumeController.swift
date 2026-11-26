import CoreAudio
import Foundation

struct VolumeController {
    func set(_ value: Float) {
        guard let device = defaultOutputDevice() else { return }
        var volume = min(1, max(0, value))
        var volumeAddress = propertyAddress(kAudioDevicePropertyVolumeScalar)
        _ = AudioObjectSetPropertyData(
            device, &volumeAddress, 0, nil,
            UInt32(MemoryLayout<Float>.size), &volume
        )

        var mute: UInt32 = volume <= 0.001 ? 1 : 0
        var muteAddress = propertyAddress(kAudioDevicePropertyMute)
        _ = AudioObjectSetPropertyData(
            device, &muteAddress, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &mute
        )
    }

    func get() -> Float? {
        guard let device = defaultOutputDevice() else { return nil }

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = propertyAddress(kAudioDevicePropertyMute)
        if AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &muteSize, &mute) == noErr,
           mute != 0 {
            return 0.0
        }

        var volumeAddress = propertyAddress(kAudioDevicePropertyVolumeScalar)
        var volume: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        guard AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &volume) == noErr,
              volume.isFinite else { return nil }
        return volume
    }

    private func defaultOutputDevice() -> AudioObjectID? {
        var defaultOutput = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(0)
        var deviceSize = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutput, 0, nil, &deviceSize, &device
        ) == noErr, device != 0 else { return nil }
        return device
    }

    private func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
