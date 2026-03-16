import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var showTitle = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            // Background image
            Image("SplashImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Dark overlay for text readability
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("FetchDish")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .opacity(showTitle ? 1 : 0)

                Text("No ads. No life stories. Just recipes.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                    .opacity(showTagline ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(2.0)) {
                showTagline = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                onFinished()
            }
        }
    }
}
