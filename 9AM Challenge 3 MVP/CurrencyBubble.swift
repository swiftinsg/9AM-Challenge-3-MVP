//
//  CurrencyBubble.swift
//  9AM Challenge 3 MVP
//
//  Coin balance shown in the navigation bar. When a reward is claimed the
//  bubble pops, glows and floats the amount that was earned up out of it.
//

import SwiftUI

struct CurrencyBubble: View {
    let amount: Int

    /// Incremented by the claiming screen each time a reward is collected.
    let claimPulse: Int

    /// Coins from the most recent claim, displayed while the bubble celebrates.
    let lastGain: Int

    @State private var scale: CGFloat = 1
    @State private var glowing = false
    @State private var floatingGain: Int?
    @State private var gainHasRisen = false
    @State private var celebrationID = UUID()

    var body: some View {
        HStack(spacing: 4) {
            Text("💰")
            Text("\(amount)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(amount)))
                .animation(.easeOut(duration: 0.35), value: amount)
        }
        .font(.dynaPuff(16).weight(.bold))
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.orange.opacity(glowing ? 0.30 : 0.16))
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(glowing ? 0.75 : 0.30), lineWidth: 1)
                )
        )
        .scaleEffect(scale)
        .shadow(
            color: .orange.opacity(glowing ? 0.45 : 0),
            radius: glowing ? 12 : 0
        )
        .overlay(alignment: .top) {
            if let gain = floatingGain {
                Text("+\(gain)")
                    .font(.dynaPuff(14).weight(.heavy))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.95))
                    )
                    .offset(y: gainHasRisen ? -34 : -10)
                    .opacity(gainHasRisen ? 0 : 1)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: claimPulse) { _, _ in
            celebrate()
        }
    }

    private func celebrate() {
        guard lastGain > 0 else { return }

        // Reset any celebration still in flight so back-to-back claims both pop.
        withAnimation(nil) {
            scale = 1
            glowing = false
            floatingGain = nil
            gainHasRisen = false
        }

        let id = UUID()
        celebrationID = id
        floatingGain = lastGain

        withAnimation(.spring(response: 0.25, dampingFraction: 0.42)) {
            scale = 1.18
            glowing = true
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.18)) {
            scale = 1
            glowing = false
        }
        withAnimation(.easeOut(duration: 0.75).delay(0.1)) {
            gainHasRisen = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard celebrationID == id else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                floatingGain = nil
            }
        }
    }
}

#Preview {
    HStack(spacing: 30) {
        CurrencyBubble(amount: 120, claimPulse: 0, lastGain: 0)
        CurrencyBubble(amount: 145, claimPulse: 0, lastGain: 25)
    }
    .padding()
}
