import Defaults
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.targetLanguage) private var targetLanguage
    @Default(.isAutoDetectEnabled) private var isAutoDetectEnabled
    @Default(.showInDock) private var showInDock
    @Default(.popupDefaultWidth) private var popupDefaultWidth
    @Default(.popupDefaultHeight) private var popupDefaultHeight
    @Default(.sourceLanguage) private var sourceLanguage
    @Default(.isLanguageDetectionEnabled) private var isLanguageDetectionEnabled
    @Default(.detectionConfidenceThreshold) private var confidenceThreshold

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Selection Translation:", name: .translateSelection)
                KeyboardShortcuts.Recorder("Screenshot OCR:", name: .ocrScreenshot)
                KeyboardShortcuts.Recorder("Manual Translation:", name: .inputTranslation)
                KeyboardShortcuts.Recorder("Clipboard Translation:", name: .clipboardTranslation)
            }

            Section("General") {
                Picker("Target Language:", selection: $targetLanguage) {
                    ForEach(SupportedLanguages.all, id: \.code) { code, name in
                        Text(name).tag(code)
                    }
                }

                Toggle("Auto-translate selected text", isOn: $isAutoDetectEnabled)

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

                Toggle("Show Dock icon", isOn: $showInDock)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        if !newValue {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
            }

            Section("Language Detection") {
                Toggle("Auto-detect source language", isOn: $isLanguageDetectionEnabled)
                    .onChange(of: isLanguageDetectionEnabled) { _, newValue in
                        if !newValue, sourceLanguage == "auto" {
                            sourceLanguage = Defaults[.targetLanguage].hasPrefix("zh") ? "en" : "zh-Hans"
                        }
                    }

                if isLanguageDetectionEnabled {
                    Picker("Preferred Source Language:", selection: $sourceLanguage) {
                        Text("No Preference").tag("auto")
                        ForEach(SupportedLanguages.all, id: \.code) { code, name in
                            Text(name).tag(code)
                        }
                    }

                    LabeledContent("Detection Sensitivity: \(confidenceThreshold, specifier: "%.1f")") {
                        Slider(value: $confidenceThreshold, in: 0.1...0.8, step: 0.1)
                    }
                    Text("Lower = more aggressive detection (may be inaccurate); Higher = more conservative (may return unknown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Source Language:", selection: $sourceLanguage) {
                        ForEach(SupportedLanguages.all, id: \.code) { code, name in
                            Text(name).tag(code)
                        }
                    }
                }
            }

            Section("Popup Panel") {
                LabeledContent("Default Width: \(popupDefaultWidth)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupDefaultWidth) },
                            set: { popupDefaultWidth = Int($0) }
                        ),
                        in: 280...800,
                        step: 10
                    )
                }

                LabeledContent("Default Height: \(popupDefaultHeight)") {
                    Slider(
                        value: Binding(
                            get: { Double(popupDefaultHeight) },
                            set: { popupDefaultHeight = Int($0) }
                        ),
                        in: 200...800,
                        step: 10
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
