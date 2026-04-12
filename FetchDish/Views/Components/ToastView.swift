import SwiftUI

struct ToastView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color("AccentGreen"))
                Text(message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text("Tap anywhere to dismiss")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .onTapGesture {
            onDismiss()
        }
    }
}
