import SwiftUI
import SwiftData
import UserNotifications
import AudioToolbox
#if os(macOS)
import AppKit
#endif

// MARK: - CookTimerManager

@Observable
final class CookTimerManager {

    // MARK: - Timer model

    struct CookTimer: Identifiable {
        let id = UUID()
        let name: String
        let totalSeconds: Int
        var remainingSeconds: Int
        var isRunning: Bool = true

        /// Fraction of time remaining: 0…1
        var fractionRemaining: Double {
            guard totalSeconds > 0 else { return 0 }
            return Double(remainingSeconds) / Double(totalSeconds)
        }

        /// Color based on urgency thresholds
        var urgencyColor: Color {
            if fractionRemaining > 0.50 { return Color(red: 0.85, green: 0.55, blue: 0.1) }
            if fractionRemaining > 0.25 { return Color(red: 0.9, green: 0.75, blue: 0.1) }
            return Color(red: 0.85, green: 0.2, blue: 0.1)
        }

        /// Formatted countdown string  (H:MM:SS or MM:SS)
        var countdownString: String {
            let s = max(0, remainingSeconds)
            let hours = s / 3600
            let minutes = (s % 3600) / 60
            let seconds = s % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Published state

    var timers: [CookTimer] = []

    // MARK: - Private

    private var ticker: Timer?
    private var notificationPermissionRequested = false

    // MARK: - API

    func start(name: String, seconds: Int) {
        requestNotificationPermissionIfNeeded()
        let timer = CookTimer(name: name, totalSeconds: seconds, remainingSeconds: seconds)
        timers.append(timer)
        ensureTickerRunning()
    }

    func remove(id: UUID) {
        timers.removeAll { $0.id == id }
        if timers.isEmpty { stopTicker() }
    }

    func removeAll() {
        timers.removeAll()
        stopTicker()
    }

    // MARK: - Tick

    @objc func tick() {
        var didFinish = false
        for index in timers.indices {
            guard timers[index].isRunning else { continue }
            if timers[index].remainingSeconds > 0 {
                timers[index].remainingSeconds -= 1
            }
            // Fire notification exactly once: when the counter first reaches zero.
            // Mark isRunning = false immediately so subsequent ticks skip this timer
            // and the notification is not re-fired before the 3-second removal window.
            if timers[index].remainingSeconds == 0 {
                timers[index].isRunning = false
                fireNotification(for: timers[index])
                didFinish = true
            }
        }
        // Remove finished timers after a short delay so the 00:00 is visible briefly
        if didFinish {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.timers.removeAll { !$0.isRunning && $0.remainingSeconds == 0 }
                if self?.timers.isEmpty == true { self?.stopTicker() }
            }
        }
    }

    // MARK: - Most urgent timer color (for the tab pill)

    var mostUrgentColor: Color {
        guard !timers.isEmpty else { return Color("AccentGreen") }
        // Lowest fractionRemaining = most urgent
        let mostUrgent = timers.min(by: { $0.fractionRemaining < $1.fractionRemaining })!
        return mostUrgent.urgencyColor
    }

    // MARK: - Helpers

    private func ensureTickerRunning() {
        guard ticker == nil else { return }
        let t = Timer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func fireNotification(for timer: CookTimer) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Done!"
        content.body = "\(timer.name) is finished."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: timer.id.uuidString,
            content: content,
            trigger: nil  // fire immediately
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        playFinishSound()
    }

    private func playFinishSound() {
        #if os(macOS)
        func playOnce(delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let sound = NSSound(contentsOfFile: "/System/Library/PrivateFrameworks/AudioPasscode.framework/Versions/A/Resources/FadingPingPong.wav", byReference: false)
                sound?.play()
            }
        }
        playOnce(delay: 0)
        playOnce(delay: 1.5)
        playOnce(delay: 3.0)
        #else
        AudioServicesPlaySystemSound(1005)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { AudioServicesPlaySystemSound(1005) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { AudioServicesPlaySystemSound(1005) }
        #endif
    }

    private func requestNotificationPermissionIfNeeded() {
        guard !notificationPermissionRequested else { return }
        notificationPermissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

// MARK: - Time expression parsing helpers

struct TimeExpression {
    let range: Range<String.Index>
    let phrase: String  // original text, e.g. "25 minutes"
    let totalSeconds: Int
}

enum TimeExpressionParser {

    // Supported patterns (case-insensitive):
    //   "1 hour 30 minutes", "2 hours", "45 minutes", "30 mins", "25 min",
    //   "10 seconds", "10 sec", "10 secs", "1 hr", "1.5 hours"
    //   Combined: "1 hour 30 min", "2 hrs 15 mins"
    private static let hourPattern = #"(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b"#
    private static let minPattern  = #"(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|m)\b"#
    private static let secPattern  = #"(\d+(?:\.\d+)?)\s*(?:seconds?|secs?|s)\b"#

    // Full combined pattern: optional hour, optional minute, optional second
    // At least one component must be present
    private static let fullPattern =
        #"(?:(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b\s*)?"# +
        #"(?:(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|m)\b\s*)?"# +
        #"(?:(\d+(?:\.\d+)?)\s*(?:seconds?|secs?|s)\b)?"#

    static func parse(in text: String) -> [TimeExpression] {
        // We search for time runs: sequences that contain at least one time unit keyword
        // Strategy: find all matches of a compound pattern
        // Use a single regex that matches at least one component
        let combined =
            #"(\d+(?:\.\d+)?)\s*(?:hours?|hrs?)\s*(?:(?:and)\s*)?(?:(\d+(?:\.\d+)?)\s*(?:minutes?|mins?))?|"# +
            #"(\d+(?:\.\d+)?)\s*(?:minutes?|mins?)|"# +
            #"(\d+(?:\.\d+)?)\s*(?:seconds?|secs?)"#

        guard let regex = try? NSRegularExpression(pattern: combined, options: [.caseInsensitive]) else {
            return []
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        var results: [TimeExpression] = []
        for match in matches {
            let nsRange = match.range
            guard let swiftRange = Range(nsRange, in: text) else { continue }
            let phrase = String(text[swiftRange])
            let seconds = secondsFrom(phrase: phrase)
            guard seconds > 0 else { continue }
            results.append(TimeExpression(range: swiftRange, phrase: phrase, totalSeconds: seconds))
        }
        return results
    }

    static func secondsFrom(phrase: String) -> Int {
        var total = 0
        let lower = phrase.lowercased()

        // Hours
        if let hourRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b"#),
           let m = hourRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let r = Range(m.range(at: 1), in: lower),
           let val = Double(lower[r]) {
            total += Int(val * 3600)
        }
        // Minutes
        if let minRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|m)\b"#),
           let m = minRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let r = Range(m.range(at: 1), in: lower),
           let val = Double(lower[r]) {
            total += Int(val * 60)
        }
        // Seconds
        if let secRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(?:seconds?|secs?|s)\b"#),
           let m = secRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let r = Range(m.range(at: 1), in: lower),
           let val = Double(lower[r]) {
            total += Int(val)
        }
        return total
    }
}

// MARK: - RepeatButton
// Fires action immediately on press, then repeats while held.
private struct RepeatButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var holdTimer: Timer?
    @State private var repeatTimer: Timer?
    @State private var isPressed: Bool = false

    var body: some View {
        label()
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        let h = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                            let r = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in
                                action()
                            }
                            RunLoop.main.add(r, forMode: .common)
                            self.repeatTimer = r
                        }
                        RunLoop.main.add(h, forMode: .common)
                        holdTimer = h
                    }
                    .onEnded { _ in
                        isPressed = false
                        holdTimer?.invalidate(); holdTimer = nil
                        repeatTimer?.invalidate(); repeatTimer = nil
                    }
            )
    }
}

// MARK: - Cook Mode Timer Sidebar
// A vertical stack of draggable circular timer dials shown on the right side in cook mode.
// Each dial represents a time expression found in the recipe instructions.
// Works on both iOS and macOS.

struct CookModeTimerSidebar: View {

    let recipe: Recipe
    @Bindable var timerManager: CookTimerManager

    // Persisted vertical offset (0 = centered)
    @AppStorage("cookTimerSidebarOffsetY") private var storedOffsetY: Double = 0

    // Local pill state
    @State private var pills: [TimerPill] = []
    // Current drag translation (while gesture is in progress)
    @State private var dragDeltaY: CGFloat = 0
    // Pulse animation for urgent timers
    @State private var pulseScale: CGFloat = 1.0
    // Blink animation for done state
    @State private var blinkOn: Bool = false
    @State private var blinkingPills: Set<UUID> = []
    // Custom timer input
    @State private var showCustomTimerInput: Bool = false
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 0
    @State private var customSeconds: Int = 0
    // Pro gating
    @State private var proManager = ProManager.shared
    @State private var showUpgradePrompt: Bool = false

    // MARK: - Design tokens
    private let creamBg     = Color(red: 0.96, green: 0.93, blue: 0.87)
    private let brownBorder = Color(red: 0.6,  green: 0.4,  blue: 0.2).opacity(0.4)
    private let darkBrown   = Color(red: 0.3,  green: 0.18, blue: 0.05)
    private let pillShadow  = Color.black.opacity(0.35)

    // Dial dimensions
    private let dialSize: CGFloat = 88
    private let innerDialSize: CGFloat = 58

    // MARK: - Pill model

    struct TimerPill: Identifiable {
        let id = UUID()
        let phrase: String
        let originalPhrase: String  // abbreviated display phrase, e.g. "10 min"
        let totalSeconds: Int
        let stepNumber: Int
        var state: PillState = .idle

        enum PillState {
            case idle
            case running(remainingSeconds: Int, timerID: UUID)
            case done
        }

        var isRunning: Bool {
            if case .running = state { return true }
            return false
        }

        var countdownString: String {
            guard case .running(let remaining, _) = state else { return "" }
            let s = max(0, remaining)
            let h = s / 3600
            let m = (s % 3600) / 60
            let sec = s % 60
            if h > 0 {
                return String(format: "%d:%02d:%02d", h, m, sec)
            }
            return String(format: "%02d:%02d", m, sec)
        }

        var fractionRemaining: Double {
            guard case .running(let remaining, _) = state else { return 1.0 }
            guard totalSeconds > 0 else { return 0 }
            return Double(remaining) / Double(totalSeconds)
        }

        var urgencyTextColor: Color {
            let fraction = fractionRemaining
            if fraction > 0.50 { return Color(red: 0.3, green: 0.85, blue: 0.4) }
            if fraction > 0.25 { return Color(red: 1.0, green: 0.82, blue: 0.2) }
            return Color(red: 1.0, green: 0.28, blue: 0.2)
        }

        var isUrgent: Bool {
            guard case .running = state else { return false }
            return fractionRemaining <= 0.25
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let currentOffsetY = CGFloat(storedOffsetY) + dragDeltaY
            let cardWidth: CGFloat = 200
            let cardHeight: CGFloat = 240
            let cardX = geo.size.width - cardWidth / 2 - dialSize - 20
            let cardYRaw = geo.size.height - cardHeight / 2 - 80
            let cardY = min(max(cardYRaw, cardHeight / 2 + 20), geo.size.height - cardHeight / 2 - 20)

            // Draggable sidebar (pills + "+" button)
            VStack(spacing: 10) {
                ForEach($pills) { $pill in
                    pillView(pill: $pill)
                }

                // Custom timer "+" button — Pro feature
                Button {
                    guard proManager.isPro else {
                        showUpgradePrompt = true
                        return
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCustomTimerInput = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.92),
                                        Color(white: 0.75),
                                        Color(white: 0.88),
                                        Color(white: 0.68)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle().stroke(Color(white: 0.5).opacity(0.6), lineWidth: 1.5)
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: pillShadow, radius: 4, x: 0, y: 2)
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(white: 0.2))
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: dialSize + 8)
            .position(
                x: geo.size.width - (dialSize / 2) - 8,
                y: geo.size.height / 2 + currentOffsetY
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragDeltaY = value.translation.height
                    }
                    .onEnded { value in
                        storedOffsetY += Double(value.translation.height)
                        dragDeltaY = 0
                    }
            )

            // Custom timer input card — anchored to bottom-left of sidebar, never off-screen
            if showCustomTimerInput {
                customTimerCard
                    .fixedSize()
                    .position(x: cardX, y: cardY)
                    .zIndex(100)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            buildPills()
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
            }
        }
        // Observe timer state changes by watching a snapshot integer that changes
        // whenever any timer's remainingSeconds changes or timers are added/removed.
        .onChange(of: timerManager.timers.map(\.remainingSeconds).reduce(0, +) + timerManager.timers.count * 1_000_000) { _, _ in
            syncPillsWithTimers()
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView(triggerMessage: "Per-step timers are a Pro feature.")
        }
    }

    // MARK: - Custom timer card

    private var customTimerCard: some View {
        let totalCustomSecs = customHours * 3600 + customMinutes * 60 + customSeconds

        return VStack(spacing: 4) {
            // Cancel button above the card, right-aligned
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showCustomTimerInput = false
                    }
                } label: {
                    Text("✕")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 200)

            // Brushed steel outer card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(white: 0.75),
                                Color(white: 0.92),
                                Color(white: 0.68),
                                Color(white: 0.88),
                                Color(white: 0.75)
                            ],
                            center: .center
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color(white: 0.5).opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)

                // Dark inner panel
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.12))
                    .frame(width: 168, height: 168)
                    .overlay(
                        VStack(spacing: 8) {
                            // H row
                            HStack(spacing: 4) {
                                Text("H")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.5))
                                Spacer()
                                RepeatButton(action: {
                                    if customHours > 0 { customHours -= 1 }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.25))
                                            .frame(width: 24, height: 24)
                                        Text("−")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                Text("\(customHours)")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 36)
                                    .multilineTextAlignment(.center)
                                RepeatButton(action: {
                                    if customHours < 23 { customHours += 1 }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.25))
                                            .frame(width: 24, height: 24)
                                        Text("+")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            // M row
                            HStack(spacing: 4) {
                                Text("M")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.5))
                                Spacer()
                                RepeatButton(action: {
                                    if customMinutes > 0 { customMinutes -= 1 }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.25))
                                            .frame(width: 24, height: 24)
                                        Text("−")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                Text("\(customMinutes)")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 36)
                                    .multilineTextAlignment(.center)
                                RepeatButton(action: {
                                    if customMinutes < 59 { customMinutes += 1 }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.25))
                                            .frame(width: 24, height: 24)
                                        Text("+")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            // S row
                            HStack(spacing: 4) {
                                Text("S")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.5))
                                Spacer()
                                RepeatButton(action: {
                                    if customSeconds > 0 { customSeconds -= 1 }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.25))
                                            .frame(width: 24, height: 24)
                                        Text("−")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                Text("\(customSeconds)")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 36)
                                    .multilineTextAlignment(.center)
                                RepeatButton(action: {
                                    if customSeconds < 59 { customSeconds += 1 }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.25))
                                            .frame(width: 24, height: 24)
                                        Text("+")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            // Start button
                            Button {
                                guard totalCustomSecs > 0 else { return }
                                let label = customTimerLabel(h: customHours, m: customMinutes, s: customSeconds)
                                timerManager.start(name: "Custom · \(label)", seconds: totalCustomSecs)
                                if let newTimer = timerManager.timers.last {
                                    let newPill = TimerPill(
                                        phrase: label,
                                        originalPhrase: label,
                                        totalSeconds: totalCustomSecs,
                                        stepNumber: 0,
                                        state: .running(remainingSeconds: totalCustomSecs, timerID: newTimer.id)
                                    )
                                    withAnimation { pills.append(newPill) }
                                }
                                HapticManager.medium()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showCustomTimerInput = false
                                    customHours = 0
                                    customMinutes = 0
                                    customSeconds = 0
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 44, height: 44)
                                    Circle()
                                        .strokeBorder(Color(white: 0.4), lineWidth: 1)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(totalCustomSecs == 0 ? Color(white: 0.4) : .white)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(totalCustomSecs == 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(width: 168, height: 168)
                    )
            }
            .frame(width: 200, height: 200)
        }
    }

    // MARK: - Dial view (the circular pill)

    @ViewBuilder
    private func pillView(pill: Binding<TimerPill>) -> some View {
        let p = pill.wrappedValue
        ZStack(alignment: .topTrailing) {
            Button {
                handlePillTap(pill: pill)
            } label: {
                let isIdle: Bool = { if case .idle = p.state { return true }; return false }()
                dialLabel(for: p)
                    .opacity(!proManager.isPro && isIdle ? 0.5 : 1.0)
            }
            .buttonStyle(.plain)
            .frame(width: dialSize, height: dialSize)
            .shadow(color: pillShadow, radius: 8, x: 0, y: 4)
            .scaleEffect(p.isUrgent ? pulseScale : 1.0)
            .animation(.easeInOut(duration: 0.3), value: p.isRunning)

            // Pro badge overlay on idle dials for free users
            if !proManager.isPro, case .idle = p.state {
                ProBadgeView(compact: true)
                    .offset(x: 4, y: -4)
            }

            // X button — only shown when done
            if case .done = p.state {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pills.removeAll { $0.id == p.id }
                    }
                    HapticManager.light()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 20, height: 20)
                        Circle()
                            .strokeBorder(Color(white: 0.45), lineWidth: 1)
                            .frame(width: 20, height: 20)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func dialLabel(for pill: TimerPill) -> some View {
        ZStack {
            // 1. Outer brushed steel ring
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(white: 0.75),
                            Color(white: 0.92),
                            Color(white: 0.68),
                            Color(white: 0.88),
                            Color(white: 0.75)
                        ],
                        center: .center
                    )
                )
                .frame(width: dialSize, height: dialSize)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.5).opacity(0.6), lineWidth: 1.5)
                )

            // 2. Tick marks canvas
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let tickCount = 60

                for i in 0..<tickCount {
                    let isMajor = i % 5 == 0
                    let outerRadius: CGFloat = 43
                    let innerRadius: CGFloat = isMajor ? 36 : 40
                    let angle = Double(i) / Double(tickCount) * 2 * .pi - .pi / 2

                    let outerPt = CGPoint(
                        x: center.x + cos(angle) * outerRadius,
                        y: center.y + sin(angle) * outerRadius
                    )
                    let innerPt = CGPoint(
                        x: center.x + cos(angle) * innerRadius,
                        y: center.y + sin(angle) * innerRadius
                    )

                    var path = Path()
                    path.move(to: innerPt)
                    path.addLine(to: outerPt)

                    // For running timers: elapsed ticks are faded, remaining are solid
                    let tickColor: Color
                    if case .running = pill.state {
                        let fraction = pill.fractionRemaining
                        let tickFraction = Double(tickCount - i) / Double(tickCount)
                        if tickFraction <= fraction {
                            tickColor = Color(white: 0.3)
                        } else {
                            tickColor = Color(white: 0.6).opacity(0.3)
                        }
                    } else {
                        tickColor = Color(white: 0.3).opacity(0.7)
                    }

                    context.stroke(
                        path,
                        with: .color(tickColor),
                        lineWidth: isMajor ? 2.0 : 1.0
                    )
                }
            }
            .frame(width: dialSize, height: dialSize)

            // 3. Inner dark dial
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.18), Color(white: 0.08)],
                        center: .center,
                        startRadius: 0,
                        endRadius: innerDialSize / 2
                    )
                )
                .frame(width: innerDialSize, height: innerDialSize)

            // 4. Done state: blinking inner dial overlay (5 blinks then stops)
            if case .done = pill.state {
                Circle()
                    .fill(blinkingPills.contains(pill.id) && blinkOn
                        ? Color(red: 0.85, green: 0.2, blue: 0.1)
                        : Color(white: 0.1)
                    )
                    .frame(width: innerDialSize, height: innerDialSize)
            }

            // 5. Center content
            dialCenter(for: pill)
        }
        .frame(width: dialSize, height: dialSize)
    }

    @ViewBuilder
    private func dialCenter(for pill: TimerPill) -> some View {
        switch pill.state {
        case .idle:
            VStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(white: 0.7))
                Text(shortPhrase(pill.phrase))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(width: innerDialSize - 8)
            }

        case .running:
            Text(pill.countdownString)
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundStyle(pill.urgencyTextColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: innerDialSize - 6)

        case .done:
            VStack(spacing: 1) {
                Text("✓")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(shortPhrase(pill.phrase))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(width: innerDialSize - 8)
            }
        }
    }

    // MARK: - Pill actions

    private func handlePillTap(pill: Binding<TimerPill>) {
        guard proManager.isPro else {
            showUpgradePrompt = true
            return
        }
        switch pill.wrappedValue.state {
        case .idle:
            // Start a timer via the manager
            let step = pill.wrappedValue.stepNumber
            let name = step > 0
                ? "Step \(step) · \(pill.wrappedValue.phrase)"
                : "Custom · \(pill.wrappedValue.phrase)"
            timerManager.start(name: name, seconds: pill.wrappedValue.totalSeconds)
            // Find the timer we just added (it's the last one)
            if let newTimer = timerManager.timers.last {
                pill.wrappedValue.state = .running(
                    remainingSeconds: pill.wrappedValue.totalSeconds,
                    timerID: newTimer.id
                )
            }
            HapticManager.medium()

        case .running(_, let timerID):
            // Cancel the timer
            timerManager.remove(id: timerID)
            pill.wrappedValue.state = .idle
            HapticManager.light()

        case .done:
            // Stop blinking and reset to idle; user can tap again to restart
            blinkingPills.remove(pill.wrappedValue.id)
            withAnimation { pill.wrappedValue.state = .idle }
            HapticManager.light()
        }
    }

    // MARK: - Sync running pills with timer manager

    private func syncPillsWithTimers() {
        for index in pills.indices {
            switch pills[index].state {
            case .running(_, let timerID):
                if let match = timerManager.timers.first(where: { $0.id == timerID }) {
                    pills[index].state = .running(remainingSeconds: match.remainingSeconds, timerID: timerID)
                    if match.remainingSeconds == 0 {
                        let pillID = pills[index].id
                        pills[index].state = .done
                        startBlinkSequence(for: pillID)
                        // Auto-reset to idle after 12 seconds so user can restart if needed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                            guard let i = self.pills.firstIndex(where: { $0.id == pillID }) else { return }
                            if case .done = self.pills[i].state {
                                self.blinkingPills.remove(pillID)
                                withAnimation { self.pills[i].state = .idle }
                            }
                        }
                    }
                } else {
                    // Timer was removed externally — go back to idle
                    pills[index].state = .idle
                }
            default:
                break
            }
        }
    }

    // MARK: - Blink sequence (5 blinks, 0.7s on / 0.7s off, then stops)

    private func startBlinkSequence(for pillID: UUID) {
        blinkingPills.insert(pillID)
        var count = 0
        func nextBlink() {
            guard blinkingPills.contains(pillID), count < 5 else {
                blinkingPills.remove(pillID)
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) { blinkOn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeInOut(duration: 0.35)) { self.blinkOn = false }
                count += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { nextBlink() }
            }
        }
        nextBlink()
    }

    // MARK: - Build pills from recipe

    private func buildPills() {
        var result: [TimerPill] = []
        let sorted = recipe.instructions.sorted(by: { $0.stepNumber < $1.stepNumber })
        for instruction in sorted {
            let expressions = TimeExpressionParser.parse(in: instruction.text)
            for expr in expressions {
                result.append(TimerPill(
                    phrase: expr.phrase,
                    originalPhrase: shortPhrase(expr.phrase),
                    totalSeconds: expr.totalSeconds,
                    stepNumber: instruction.stepNumber
                ))
            }
        }
        // DEBUG: if no time expressions found show a placeholder so the sidebar
        // is visually confirmed to render. Remove once confirmed working.
        if result.isEmpty {
            result.append(TimerPill(phrase: "5 min", originalPhrase: "5 min", totalSeconds: 300, stepNumber: 1))
        }
        pills = result
    }

    // MARK: - Helpers

    private func shortPhrase(_ phrase: String) -> String {
        // Abbreviate "minutes" → "min", "seconds" → "sec", "hours" → "hr"
        var s = phrase
            .replacingOccurrences(of: "minutes", with: "min")
            .replacingOccurrences(of: "minute", with: "min")
            .replacingOccurrences(of: "seconds", with: "sec")
            .replacingOccurrences(of: "second", with: "sec")
            .replacingOccurrences(of: "hours", with: "hr")
            .replacingOccurrences(of: "hour", with: "hr")
        // Keep it under ~12 chars for the dial width
        if s.count > 12 { s = String(s.prefix(12)) }
        return s
    }

    private func customTimerLabel(h: Int, m: Int, s: Int) -> String {
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if s > 0 { parts.append("\(s)s") }
        return parts.isEmpty ? "0s" : parts.joined(separator: " ")
    }
}
