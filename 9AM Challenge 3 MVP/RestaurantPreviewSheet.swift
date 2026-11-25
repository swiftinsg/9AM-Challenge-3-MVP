//
//  RestaurantPreviewSheet.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//


import SwiftUI

struct RestaurantPreviewSheet: View {

    let restaurant: Restaurant
    let reason: String
    var adherence: DietAdherence?

    @Environment(\.dismiss) private var dismiss

    @State private var showFullDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Restaurant information
            HStack(spacing: 15) {
                Text(restaurant.emoji)
                    .font(.dynaPuff(65))
                    .frame(width: 100, height: 100)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(.dynaPuff(22))
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Text(restaurant.description)
                        .font(.dynaPuff(15))
                        .foregroundStyle(AppColor.secondaryText)

                    Label(restaurant.area, systemImage: "mappin.circle")
                        .font(.dynaPuff(13))
                }
            }

            Divider()

            Text(
                restaurant.summary.isEmpty
                    ? "A little taste of what's waiting for you!"
                    : restaurant.summary
            )
            .font(.dynaPuff(15))
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            // Mascot explanation in bottom-right
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reason)
                        .font(.dynaPuff(15))
                        .padding(12)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let adherence {
                        MunchkinDietMessage(
                            adherence: adherence,
                            showMascot: false
                        )
                    }
                }

                MunchkinAvatarView(size: 45)
            }

            Button {
                showFullDetails = true
            } label: {
                Text("View Full Details →")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(20)
        .background(AppColor.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showFullDetails) {
            NavigationStack {
                RestaurantDetailView(restaurant: restaurant)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showFullDetails = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    RestaurantPreviewSheet(
        restaurant: .preview,
        reason: "You love bold, spicy flavours, so I thought you'd enjoy this!"
    )
}
