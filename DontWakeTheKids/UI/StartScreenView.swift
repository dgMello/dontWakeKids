import SwiftUI

struct StartScreenView: View {
    let onPlay: () -> Void
    @State private var showRules = false

    var body: some View {
        ZStack {
            Color.night.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                moonIcon
                Spacer().frame(height: 40)
                titleBlock
                Spacer()
                buttonStack
                Spacer().frame(height: 56)
            }
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRules) {
            RulesView()
        }
    }

    private var moonIcon: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.amber)
                .shadow(color: Color.amber.opacity(0.4), radius: 20)
            Text("5:30 AM")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(3)
                .foregroundStyle(Color.muted)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("Don't Wake\nthe Kids")
                .font(Fonts.hand(44, bold: true))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Text("Get through your morning without waking a soul.")
                .font(Fonts.hand(17))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var buttonStack: some View {
        VStack(spacing: 14) {
            PrimaryButton(title: "Start My Morning", action: onPlay)
            Button("How to Play") { showRules = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.muted)
                .frame(minHeight: 44)
        }
    }
}

#Preview {
    StartScreenView(onPlay: {})
}
