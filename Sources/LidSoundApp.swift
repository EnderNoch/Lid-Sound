import ServiceManagement
import SwiftUI

/// The app's name in the system language, from the bundle (build.sh writes it there).
let appName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
    ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Lid Sound"

/// Lives only in the menu bar: nothing to look at while it works, so no window and no Dock icon.
@main
struct LidSoundApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        // Always there; hiding it is System Settings → Menu Bar's job, and it keeps its place.
        MenuBarExtra {
            Panel()
        } label: {
            MenuBarLabel()
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

                Picker(s.menuBar, selection: $player.menuBar) {
                    ForEach(MenuBarStyle.allCases) { Text($0.name(s)).tag($0) }
                }

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

/// What the menu bar shows, like the battery: just the icon, the angle as text, or the angle
/// inside the icon the way the battery shows its percentage.
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case icon, angle, angleInIcon
    var id: Self { self }

    func name(_ s: Strings) -> String {
        switch self {
        case .icon: s.icon
        case .angle: s.angle
        case .angleInIcon: s.angleInIcon
        }
    }
}

struct MenuBarLabel: View {
    private let player = Player.shared
    private let sensor = Sensor.shared

    var body: some View {
        Group {
            switch (player.menuBar, sensor.angle) {
            case (.angle, let angle?):
                Text("\(angle)°").monospacedDigit()
            case (.angleInIcon, let angle?):
                Image(nsImage: Self.icon(angle: angle, dimmed: !player.enabled))
            default:
                Image(systemName: player.enabled ? "laptopcomputer" : "laptopcomputer.slash")
            }
        }
        .accessibilityLabel(sensor.angle.map { player.s.lidAngle($0) } ?? appName)
    }

    /// The icon itself, unchanged (the system's "laptopcomputer" at menu bar size, 22 × 13
    /// points), with the angle written on its screen. The digits are the system's compressed
    /// face, as large as fits inside the screen's lines. A template image, so the menu bar
    /// colors it; half strength while the sound is off.
    private static func icon(angle: Int, dimmed: Bool) -> NSImage {
        let laptop = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))!
        // The symbol's screen inside its lines: 12.6 wide from x 4.6, 8.1 high from y 2.25.
        let screen = NSRect(x: 4.6, y: 2.25, width: 12.6, height: 8.1)
        let text = "\(angle)" as NSString
        func font(_ size: Double) -> NSFont {
            let compressed = NSFont.systemFont(ofSize: size, weight: .bold, width: .compressed)
            let digits = compressed.fontDescriptor.addingAttributes([.featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                .selectorIdentifier: kMonospacedNumbersSelector,
            ]]])
            return NSFont(descriptor: digits, size: size) ?? compressed
        }
        let largest = 9.0
        let room = screen.width - 0.6
        let width = text.size(withAttributes: [.font: font(largest)]).width
        let digits = font(width > room ? largest * room / width : largest)
        let attributes: [NSAttributedString.Key: Any] = [.font: digits, .foregroundColor: NSColor.black]
        let textWidth = text.size(withAttributes: attributes).width
        let image = NSImage(size: laptop.size, flipped: false) { bounds in
            laptop.draw(in: bounds)
            // Digits centred on their cap height, not on the line with its descender.
            let y = screen.midY - digits.capHeight / 2 + digits.descender
            text.draw(at: NSPoint(x: screen.midX - textWidth / 2, y: y), withAttributes: attributes)
            NSColor.black.set()
            bounds.fill(using: .sourceAtop)
            if dimmed {
                NSColor.black.withAlphaComponent(0.5).set()
                bounds.fill(using: .destinationIn)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
