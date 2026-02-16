import Defaults
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.targetLanguage) private var targetLanguage

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let languages = [
        ("zh-Hans", "Simplified Chinese"),
        ("zh-Hant", "Traditional Chinese"),
        ("en", "English"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
    ]

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Translate Selection:", name: .translateSelection)
                KeyboardShortcuts.Recorder("OCR Screenshot:", name: .ocrScreenshot)
            }

            Section("General") {
                Picker("Target Language:", selection: $targetLanguage) {
                    ForEach(languages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue // Revert on failure
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
