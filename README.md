# EdgeBar MVP

EdgeBar is a menu bar prototype that maps a single-finger slide along the left trackpad edge to built-in display brightness and the right edge to system output volume. The touch must begin inside the outer 4% band; a slide of at least 2.5% of trackpad height lasting at least 100 ms activates adjustment. Further movement adjusts relative to the current system level. Taps and stationary touches do not change levels.

## Build status

This project targets macOS 15+ and Swift 6.2+. Its global touch input uses OpenMultitouchSupport 4.0.0, which wraps Apple's private `MultitouchSupport` framework. App Sandbox must be disabled. Brightness uses dynamically loaded private `DisplayServices`; volume uses Core Audio.

Run `swift run --build-system native` from this directory. The app successfully compiled and linked with the installed Command Line Tools on 2026-11-23 using this alternate build system. The default build system fails to initialize in this environment. The native build system is deprecated, so this is a local development workaround. No hardware input or output adjustment has been validated.

## Known MVP limits

- Private multitouch and brightness APIs can change across macOS updates and prevent Mac App Store distribution.
- The touch coordinate orientation and edge threshold need calibration on real built-in trackpads.
- Volume changes can fail for output devices without a writable master volume property.
- No gesture conflict handling, click passthrough measurement, onboarding, persistence, or external display selection yet.
- Input Monitoring prompt behavior must be checked with the packaged app on target macOS versions.

## Next MVP work

1. Build and launch as a signed `.app` with App Sandbox disabled; confirm the global touch callback starts and document any Input Monitoring prompt.
2. Measure edge coordinates, touch state transitions, orientation, accidental activation, and click/system-gesture interference on the actual MacBook trackpad.
3. Tune activation width, smoothing, and release behavior from those observations.
4. Add user-selectable edge mapping and a safe enable/disable control before considering background launch.

## Haptic feedback

An alignment pulse is requested when an edge activates and after each additional 10 percentage points of movement. Pulses are limited to one per 80 ms during sliding. Use the Haptic feedback toggle in the menu to turn it off. Feedback uses Apple’s public NSHapticFeedbackManager API and depends on a compatible Force Touch trackpad and system preferences. Physical feedback, including while another app is active, has not been validated.
