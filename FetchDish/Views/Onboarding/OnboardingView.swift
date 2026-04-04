import SwiftUI

struct OnboardingView: View {
    let onDismiss: () -> Void

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var currentPage: Int = 0
    private let totalPages = 13

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark background
                Color.black.opacity(0.72)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Skip — sits just above the slide image, hidden on last page
                    if currentPage < totalPages - 1 {
                        Button { dismiss() } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.black.opacity(0.3)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 40) // placeholder to keep layout stable
                    }

                    Spacer().frame(height: 12)

                    // Slide images — full width
                    ZStack {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Image("Screen\(String(format: "%02d", index + 1))")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width)
                                .opacity(index == currentPage ? 1 : 0)
                        }
                    }
                    .frame(width: geo.size.width)
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
                    .gesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                if value.translation.width < -50, currentPage < totalPages - 1 {
                                    withAnimation(.easeInOut(duration: 0.35)) { currentPage += 1 }
                                } else if value.translation.width > 50, currentPage > 0 {
                                    withAnimation(.easeInOut(duration: 0.35)) { currentPage -= 1 }
                                }
                            }
                    )

                    // Below image: left arrow | dots | right arrow
                    HStack(spacing: 24) {
                        // Left arrow
                        if currentPage > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) { currentPage -= 1 }
                            } label: { navCircle(systemName: "chevron.left") }
                            .buttonStyle(.plain)
                        } else {
                            navCircle(systemName: "chevron.left").opacity(0).allowsHitTesting(false)
                        }

                        // Page dots
                        HStack(spacing: 8) {
                            ForEach(0..<totalPages, id: \.self) { index in
                                Circle()
                                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                                    .frame(width: index == currentPage ? 9 : 6, height: index == currentPage ? 9 : 6)
                                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                            }
                        }

                        // Right arrow or Get Started
                        if currentPage == totalPages - 1 {
                            Button { dismiss() } label: {
                                Text("Get Started")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .background(Capsule().fill(Color.white.opacity(0.2)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) { currentPage += 1 }
                            } label: { navCircle(systemName: "chevron.right") }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        #if os(iOS)
        .ignoresSafeArea()
        #endif
    }

    // MARK: - Helpers

    private func dismiss() {
        hasSeenOnboarding = true
        onDismiss()
    }

    private func navCircle(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 48, height: 48)
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

#Preview {
    OnboardingView(onDismiss: {})
}
