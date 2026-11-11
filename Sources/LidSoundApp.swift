import ServiceManagement
import SwiftUI

/// The app's name in the system language, from the bundle (build.sh writes it there).
let appName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
    ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Lid Sound"

/// Lives only in the menu bar: nothing to look at while it works, so no window and no Dock icon.
@main
struct LidSoundApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    private let player = Player.shared

    var body: some Scene {
        // Always there; hiding it is System Settings → Menu Bar's job, and it keeps its place.
        MenuBarExtra {
            Panel()
        } label: {
            Image(systemName: player.enabled ? "laptopcomputer" : "laptopcomputer.slash")
                .accessibilityLabel(appName)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opens at login from the first launch. Only once: switching it off is System
        // Settings → General → Login Items' job, and a later launch mustn't undo that.
        let ud = UserDefaults.standard
        if !ud.bool(forKey: "loginSetUp") {
            try? SMAppService.mainApp.register()
            ud.set(true, forKey: "loginSetUp")
        }
        Player.shared.start()
        Sensor.shared.start { Player.shared.update(velocity: $0) }
    }
}

struct Panel: View {
    private let player = Player.shared
    private let sensor = Sensor.shared

    var body: some View {
        @Bindable var player = player
        let s = player.s

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(appName).font(.headline)
                Spacer()
                if let angle = sensor.angle {
                    Text("\(angle)°").monospacedDigit().foregroundStyle(.secondary)
                }
            }

            if sensor.angle == nil {
                Text(s.noSensor).foregroundStyle(.secondary)
            } else {
                Toggle(s.on, isOn: $player.enabled).toggleStyle(.switch)

                Picker(s.sound, selection: $player.soundID) {
                    ForEach(player.sounds) { Text($0.name).tag($0.id) }
                }

                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $player.volume, in: 0...1)
                        .accessibilityLabel(s.volume)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                .disabled(!player.enabled)

                Divider()

                Button(s.folder) { player.openFolder() }
                Text(s.folderHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button(s.quit) { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 300)
        // A file just dropped into the Sounds folder shows up the next time the panel opens.
        .onAppear { player.rescan() }
    }
}
