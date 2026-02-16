import ProjectDescription

let project = Project(
    name: "MoePeek",
    settings: .settings(
        base: [
            "INFOPLIST_KEY_LSUIElement": "YES",
            "INFOPLIST_KEY_NSAccessibilityUsageDescription":
                "MoePeek needs accessibility access to read selected text.",
            "INFOPLIST_KEY_NSScreenCaptureUsageDescription":
                "MoePeek needs screen capture for OCR translation.",
            "SWIFT_STRICT_CONCURRENCY": "complete",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .target(
            name: "MoePeek",
            destinations: .macOS,
            product: .app,
            bundleId: "com.nahida.MoePeek",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            entitlements: .file(path: "Entitlements/MoePeek.entitlements"),
            dependencies: [
                .external(name: "KeyboardShortcuts"),
                .external(name: "Defaults"),
            ]
        ),
    ]
)
