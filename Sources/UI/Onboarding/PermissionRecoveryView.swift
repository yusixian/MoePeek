import SwiftUI

/// Simplified view shown when permissions are lost after an app update.
/// Displays permission status cards and auto-closes once all are re-granted.
struct PermissionRecoveryView: View {
    let permissionManager: PermissionManager
    let onAllGranted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("Permissions Need Re-Authorization")
                .font(.title2.bold())

            Text("After updating, macOS may revoke previously granted permissions. Please re-authorize below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                PermissionCardView(
                    icon: "hand.raised",
                    title: "Accessibility",
                    description: "Required for reading selected text",
                    isGranted: permissionManager.isAccessibilityGranted,
                    onOpenSettings: { permissionManager.openAccessibilitySettings() }
                )

                PermissionCardView(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Required for OCR screenshot translation",
                    isGranted: permissionManager.isScreenRecordingGranted,
                    onOpenSettings: { permissionManager.openScreenRecordingSettings() }
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onChange(of: permissionManager.allPermissionsGranted) {
            if permissionManager.allPermissionsGranted {
                onAllGranted()
            }
        }
    }
}
