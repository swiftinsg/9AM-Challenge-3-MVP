//
//  RegionFilterBar.swift
//  9AM Challenge 3 MVP
//
//  Shared region filter used across recommendations and the mixer.
//

import SwiftUI

struct RegionFilterBar: View {
    @Binding var selection: String

    /// Weekly recommendations use "Near Me" for the unrestricted option and
    /// then sort those picks by distance.
    var usesNearMeLabel = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RestaurantRegion.allCases) { region in
                    let isSelected = selection == region.rawValue
                    let isNearMeOption = usesNearMeLabel && region.isAnywhere
                    let title = isNearMeOption ? "Near Me" : region.rawValue

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selection = region.rawValue
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(
                                systemName: isNearMeOption
                                    ? "location.fill"
                                    : (region.isAnywhere
                                        ? "globe.asia.australia.fill"
                                        : "mappin.circle.fill")
                            )
                            .font(.dynaPuff(13))

                            Text(title)
                        }
                        .font(.dynaPuff(15).weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : AppColor.filterText
                        )
                        .background(
                            isSelected ? Color.orange : AppColor.card
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter by \(title)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    RegionFilterBar(selection: .constant("Central"))
        .padding()
        .background(AppColor.background)
}
