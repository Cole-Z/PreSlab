import SwiftUI
import SwiftData

struct AppRootView: View {
    @State private var startup = AppStartup()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let container = startup.container {
                LibraryView()
                    .modelContainer(container)
                    .transition(.opacity)
            } else {
                StartupView(failed: startup.failed) {
                    Task { await startup.load() }
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: startup.container != nil)
        .task { await startup.load() }
    }
}

private struct StartupView: View {
    var failed: Bool
    var retry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("LaunchBackground").ignoresSafeArea()
                // These dimensions and position match LaunchScreen.storyboard,
                // so the system launch image flows into the live loading view.
                VStack(spacing: 24) {
                    Image("LaunchMark")
                        .resizable()
                        .frame(width: 160, height: 160)
                        .overlay {
                            if !reduceMotion && !failed {
                                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
                                    Rectangle()
                                        .fill(Color.cyan.opacity(0.85))
                                        .frame(width: 112, height: 2)
                                        .shadow(color: .cyan, radius: 6)
                                        .offset(y: CGFloat(sin(phase * 2 * .pi)) * 58)
                                }
                            }
                        }
                        .accessibilityHidden(true)
                    Text("PreSlab")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(height: 38)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 30)

                VStack(spacing: 12) {
                    if failed {
                        Text("Your library couldn’t be opened.")
                            .font(.subheadline.weight(.medium))
                        Button("Try again", action: retry)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("startupRetryButton")
                    } else {
                        ProgressView().tint(.cyan)
                        Text("Opening your library…")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: geometry.size.width - 48)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + 140)
                .accessibilityIdentifier(failed ? "startupError" : "startupLoading")
            }
        }
        .ignoresSafeArea()
    }
}
