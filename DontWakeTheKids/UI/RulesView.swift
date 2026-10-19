import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.night.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ruleCard(icon: "flag.fill", title: "Goal") {
                        "Get through your morning routine and out the front door before the 6:15 AM train. If the baby or Maya wake up, your morning is over."
                    }
                    ruleCard(icon: "figure.walk", title: "Moving") {
                        "Tap any floor tile to walk there. Toggle Tiptoe mode to move quietly — but much slower. Some floorboards creak loudly when stomped on; discover them to learn which tiles to avoid."
                    }
                    ruleCard(icon: "checklist", title: "Morning Tasks") {
                        "Stand next to a station to see its tasks. Stations: Closet (get dressed), Sink (wash up), Shower, Coffee machine, Fridge (pack lunch), Back door (let Pickles outside). Tasks take time and make noise — louder ones stir the kids faster."
                    }
                    ruleCard(icon: "exclamationmark.triangle.fill", title: "Dangers") {
                        "Pickles the dog barks if you stomp near his bed — a big noise spike. Creaky floorboards are much louder unless you're tiptoeing. The train leaves at 6:15 no matter what."
                    }
                    ruleCard(icon: "star.fill", title: "Scoring") {
                        "Your score depends on tasks completed, time left on the clock, and how close the kids came to waking. Completing every task and grinding fresh coffee earns the highest stars."
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("How to Play")
                .font(Fonts.hand(28, bold: true))
                .foregroundStyle(Color.ink)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.muted)
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func ruleCard(icon: String, title: String, body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.amber)
                    .frame(width: 20)
                Text(title)
                    .font(Fonts.hand(19, bold: true))
                    .foregroundStyle(Color.amber)
            }
            Text(body())
                .font(.body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
    }
}

#Preview {
    RulesView()
}
