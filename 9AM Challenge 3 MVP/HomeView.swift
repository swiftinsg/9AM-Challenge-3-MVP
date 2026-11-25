//
//  HomeView.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//

import SwiftUI

struct HomeView: View {
    @State private var activeGoals: [GoalItem] = []
    @State private var claimableGoals: [GoalItem] = []
    @State private var currency = 0
    @State private var claimPulse = 0
    @State private var lastClaimGain = 0
    @State private var personaSnapshot = FoodPersonaStore.resolve()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Are you ready for your next food adventure?")
                        .font(.dynaPuff(15))
                        .foregroundStyle(AppColor.secondaryText)
                        .bold()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 700, alignment: .leading)

                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Your Food Persona")
                                .font(.dynaPuff(17))

                            Spacer()

                            Text("\(personaSnapshot.reviewCount) \(personaSnapshot.reviewCount == 1 ? "rating" : "ratings")")
                                .font(.dynaPuff(13))
                                .foregroundStyle(AppColor.secondaryText)
                        }

                        HStack(spacing: 15) {
                            MunchkinAvatarView(persona: personaSnapshot.persona, size: 65)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(personaSnapshot.persona.name)
                                    .font(.dynaPuff(20))
                                    .fontWeight(.medium)

                                Text(personaSnapshot.persona.tagline)
                                    .font(.dynaPuff(15))
                                    .foregroundStyle(AppColor.secondaryText)
                            }

                            Spacer()
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 700)
                    .background(personaSnapshot.persona.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goals Left For This Month")
                            .font(.dynaPuff(17))

                        if activeGoals.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "target")
                                    .font(.dynaPuff(22))
                                    .foregroundStyle(.green)

                                Text("No active goals.\nSet some in the Goals tab.")
                                    .font(.dynaPuff(13))
                                    .foregroundStyle(AppColor.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 70)
                        } else {
                            ForEach(activeGoals) { goal in
                                GoalProgressRow(
                                    title: goal.title,
                                    progress: goal.progress,
                                    total: goal.target
                                )
                            }
                        }

                        if !claimableGoals.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Ready to Claim", systemImage: "gift.fill")
                                    .font(.dynaPuff(13).weight(.semibold))
                                    .foregroundStyle(.green)

                                ForEach(claimableGoals) { goal in
                                    Button {
                                        claimReward(goal)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(goal.title)
                                                .font(.dynaPuff(13))
                                                .lineLimit(1)

                                            Spacer(minLength: 6)

                                            Text("Claim +💰\(GoalReward.coins(for: goal.difficulty))")
                                                .font(.dynaPuff(13).weight(.bold))
                                                .foregroundStyle(.green)
                                        }
                                        .padding(.vertical, 9)
                                        .padding(.horizontal, 12)
                                        .background(Color.green.opacity(0.14))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Claim reward for \(goal.title)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 700)
                    .background(AppColor.lavender)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    WeeklyRecommendationsSection()
                        .padding(20)
                        .background(AppColor.peach)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .frame(maxWidth: 700)
                }
                .padding(.horizontal, 16)
                .onAppear {
                    loadGoals()
                    personaSnapshot = FoodPersonaStore.resolve()
                }
            }
            .navigationTitle("Hello Munchkin!")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CurrencyBubble(
                        amount: currency,
                        claimPulse: claimPulse,
                        lastGain: lastClaimGain
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .personaDidChange)) { _ in
            // Onboarding picks the starting pet behind its sheet; refresh here
            // so Home already shows the new Munchkin when the sheet closes.
            personaSnapshot = FoodPersonaStore.resolve(force: true)
        }
    }

    private func loadGoals() {
        let savedGoals = UserDefaults.standard.data(forKey: "goals_v1")
            .flatMap { try? JSONDecoder().decode([GoalItem].self, from: $0) } ?? []

        activeGoals = savedGoals.filter { $0.completedAt == nil }
        claimableGoals = savedGoals.filter {
            $0.completedAt != nil && $0.rewardClaimed != true
        }

        currency = UserDefaults.standard.integer(forKey: "goal_currency_v1")
    }

    private func claimReward(_ goal: GoalItem) {
        let reward = GoalReward.coins(for: goal.difficulty)
        GoalClaim.claim(goal.id)
        loadGoals()
        lastClaimGain = reward
        claimPulse += 1
    }
}

#Preview {
    HomeView()
}
