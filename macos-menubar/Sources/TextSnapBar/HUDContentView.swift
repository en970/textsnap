import SwiftUI

final class HUDStateHolder: ObservableObject {
    @Published var state: HUDContentView.HUDState = .processing
}

struct HUDContentView: View {
    enum HUDState { case processing, success, failure }

    static let size = CGSize(width: 220, height: 84)

    @ObservedObject var stateHolder: HUDStateHolder
    @State private var pulse = false

    private var state: HUDState { stateHolder.state }

    var body: some View {
        ZStack {
            Image(decorative: DitherGradient.cached, scale: 2)
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)

            HStack(spacing: 10) {
                icon
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse && state == .processing ? 1.08 : 1.0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if state == .processing {
                        dots
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .processing: Image(systemName: "viewfinder.circle.fill")
        case .success: Image(systemName: "checkmark.circle.fill")
        case .failure: Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var title: String {
        switch state {
        case .processing: return "Reading text"
        case .success: return "Copied to clipboard"
        case .failure: return "Couldn't read text"
        }
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 4, height: 4)
                    .opacity(pulse ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: pulse
                    )
            }
        }
    }
}
