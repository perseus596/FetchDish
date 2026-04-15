import SwiftUI

/// Small "Pro" badge with lock icon. Drop on any locked feature.
struct ProBadgeView: View {
    var compact: Bool = false

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.2)

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: compact ? 8 : 10, weight: .bold))
            Text("Pro")
                .font(.system(size: compact ? 8 : 10, weight: .bold))
        }
        .foregroundStyle(.black.opacity(0.8))
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.4),
                    Color(red: 0.95, green: 0.75, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: gold.opacity(0.4), radius: 3, y: 1)
    }
}
