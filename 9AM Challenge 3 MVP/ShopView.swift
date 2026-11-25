//
//  ShopView.swift
//  9AM Challenge 3 MVP
//
//  Created by Ashmi Sharma on 13/11/26.
//

import SwiftUI

// MARK: - Accessory model

enum AccessoryCategory: String, CaseIterable, Identifiable {
    case head
    case face
    case neck
    case extra

    var id: String { rawValue }

    var title: String {
        switch self {
        case .head: return "Head"
        case .face: return "Face"
        case .neck: return "Neck"
        case .extra: return "Extra"
        }
    }

    var emoji: String {
        switch self {
        case .head: return "🎩"
        case .face: return "🕶️"
        case .neck: return "🌺"
        case .extra: return "☂️"
        }
    }

    // Where the accessory sits on the munchkin preview.
    // Tuned for the ~115pt munchkin emoji.
    var previewOffset: CGSize {
        switch self {
        case .head: return CGSize(width: 0, height: -52)
        case .face: return CGSize(width: 0, height: -6)
        case .neck: return CGSize(width: 0, height: 70)
        case .extra: return CGSize(width: 78, height: 26)
        }
    }

    var previewSize: CGFloat {
        switch self {
        case .head: return 98
        case .face: return 66
        case .neck: return 58
        case .extra: return 66
        }
    }
}

struct ShopAccessory: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let price: Int
    let category: AccessoryCategory
    let about: String
    /// How many accessories the user must own before this one is revealed.
    let unlockRequirement: Int

    // Some emoji sit differently inside their box, so they can nudge the
    // preview position/size. Nil falls back to the category default.
    var previewOffsetOverride: CGSize? = nil
    var previewSizeOverride: CGFloat? = nil

    var previewOffset: CGSize {
        previewOffsetOverride ?? category.previewOffset
    }

    var previewSize: CGFloat {
        previewSizeOverride ?? category.previewSize
    }

    /// Coins returned when selling this accessory back to the shop.
    /// Half the purchase price, rounded down.
    var sellValue: Int {
        max(1, price / 2)
    }
}

enum ShopCatalogue {
    static let items: [ShopAccessory] = [
        ShopAccessory(
            id: "party_hat", name: "Party Hat", emoji: "🎩", price: 15, category: .head,
            about: "A dapper top hat for fancy food outings.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 0, height: -56),
            previewSizeOverride: 98
        ),
        ShopAccessory(
            id: "pink_bow", name: "Pink Bow", emoji: "🎀", price: 20, category: .head,
            about: "A little sweetness with every bite.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 0, height: -25),
            previewSizeOverride: 60
        ),
        ShopAccessory(
            id: "adventure_hat", name: "Adventure Hat", emoji: "👒", price: 25, category: .head,
            about: "For adventurous restaurant runs and snack hauls.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 15, height: -50),
            previewSizeOverride: 92
        ),
        ShopAccessory(
            id: "graduation_cap", name: "Graduation Cap", emoji: "🎓", price: 40, category: .head,
            about: "For a munchkin with big foodie dreams.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 12, height: -52),
            previewSizeOverride: 92
        ),
        ShopAccessory(
            id: "royal_crown", name: "Royal Crown", emoji: "👑", price: 60, category: .head,
            about: "For the true ruler of the food court.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 0, height: -58),
            previewSizeOverride: 86
        ),
        ShopAccessory(
            id: "foodie_specs", name: "Foodie Specs", emoji: "👓", price: 15, category: .face,
            about: "Helps you spot the best dish on the menu.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 0, height: 14),
            previewSizeOverride: 64
        ),
        ShopAccessory(
            id: "cool_shades", name: "Cool Shades", emoji: "🕶️", price: 30, category: .face,
            about: "Too cool for bland food.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 0, height: 14),
            previewSizeOverride: 68
        ),
        ShopAccessory(
            id: "swim_goggles", name: "Snorkel Goggles", emoji: "🥽", price: 40, category: .face,
            about: "For diving straight into the dessert menu.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 0, height: 11),
            previewSizeOverride: 70
        ),
        ShopAccessory(
            id: "tropical_lei", name: "Tropical Lei", emoji: "🌺", price: 45, category: .head,
            about: "Holiday vibes, even on a Tuesday lunch.", unlockRequirement: 4,
            previewOffsetOverride: CGSize(width: 16, height: -40),
            previewSizeOverride: 44
        ),
        ShopAccessory(
            id: "butterfly_pin", name: "Butterfly Pin", emoji: "🦋", price: 55, category: .head,
            about: "A flutter of colour for the fanciest foodie.", unlockRequirement: 6,
            previewOffsetOverride: CGSize(width: 16, height: -40),
            previewSizeOverride: 44
        ),
        ShopAccessory(
            id: "lucky_umbrella", name: "Lucky Umbrella", emoji: "☂️", price: 35, category: .extra,
            about: "Always ready for a rainy-day snack run.", unlockRequirement: 0,
            previewOffsetOverride: CGSize(width: 78, height: 26),
            previewSizeOverride: 66
        )
    ]
}

// MARK: - Shop

struct ShopView: View {
    private enum ShopTab: String, CaseIterable, Identifiable {
        case buy
        case munchkin

        var id: String { rawValue }

        var title: String {
            switch self {
            case .buy: return "Buy"
            case .munchkin: return "My Munchkin"
            }
        }
    }

    @State private var tab: ShopTab = .buy
    @State private var selectedItem: ShopAccessory?
    @State private var saleCandidate: ShopAccessory?

    // Shares the coin balance with the Goals tab.
    @AppStorage("goal_currency_v1") private var coins = 0
    @AppStorage("shop_owned_v1") private var ownedRaw = ""
    @AppStorage("shop_equipped_v1") private var equippedRaw = ""

    private let backgroundColor = AppColor.background
    private let mintColor = AppColor.shopMint
    private let deepGreen = AppColor.greenInk

    private let itemColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let inventoryColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                subtitle

                Picker("Shop section", selection: $tab) {
                    ForEach(ShopTab.allCases) { shopTab in
                        Text(shopTab.title).tag(shopTab)
                    }
                }
                .pickerStyle(.segmented)
                .tint(.orange)

                if tab == .buy {
                    buySection
                } else {
                    munchkinSection
                }
            }
            .padding(20)
        }
        .background(backgroundColor)
        .navigationTitle("Munchkin Shop")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("💰 \(coins)")
                    .font(.dynaPuff(17))
                    .foregroundStyle(.orange)
            }
        }
        .sheet(item: $selectedItem) { item in
            AccessoryDetailSheet(
                item: item,
                coins: coins,
                owned: ownedIDs.contains(item.id),
                wearing: equipped[item.category] == item.id,
                unlocked: isUnlocked(item),
                onBuy: { buy(item) },
                onToggleWear: { toggleEquip(item) },
                onSell: { sell(item) }
            )
        }
        .alert(
            "Sell \(saleCandidate?.name ?? "accessory")?",
            isPresented: Binding(
                get: { saleCandidate != nil },
                set: { if !$0 { saleCandidate = nil } }
            ),
            presenting: saleCandidate
        ) { item in
            Button("Sell for 💰 \(item.sellValue)", role: .destructive) {
                sell(item)
            }
            Button("Cancel", role: .cancel) { }
        } message: { item in
            Text("You'll get 💰 \(item.sellValue) back. You can buy it again later.")
        }
    }

    // MARK: Header

    private var subtitle: some View {
        Text("Spend your goal coins on a new look!")
            .font(.dynaPuff(15))
            .foregroundStyle(AppColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Buy

    private var buySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accessories")
                .font(.dynaPuff(22))
                .fontWeight(.medium)

            Text("Tap an accessory to buy, wear or sell it.")
                .font(.dynaPuff(13))
                .foregroundStyle(AppColor.secondaryText)

            LazyVGrid(columns: itemColumns, spacing: 12) {
                ForEach(ShopCatalogue.items) { item in
                    itemTile(item)
                }
            }

            Label("Complete goals to earn more coins.", systemImage: "target")
                .font(.dynaPuff(13))
                .foregroundStyle(AppColor.secondaryText)
                .padding(.top, 4)
        }
    }

    private func itemTile(_ item: ShopAccessory) -> some View {
        let owned = ownedIDs.contains(item.id)
        let unlocked = isUnlocked(item)
        let affordable = coins >= item.price

        return Button {
            selectedItem = item
        } label: {
            VStack(spacing: 8) {
                Text(owned || unlocked ? item.emoji : "?")
                    .font(.dynaPuff(46).weight(.medium))
                    .foregroundStyle(
                        owned || unlocked ? Color.primary : deepGreen.opacity(0.6)
                    )
                    .frame(height: 56)

                Text(owned || unlocked ? item.name : "Mystery item")
                    .font(.dynaPuff(15).weight(.semibold))
                    .foregroundStyle(owned || unlocked ? Color.primary : AppColor.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Group {
                    if owned {
                        Label("Owned", systemImage: "checkmark.seal.fill")
                            .font(.dynaPuff(11).weight(.medium))
                            .foregroundStyle(deepGreen)
                    } else if !unlocked {
                        Label("Own \(item.unlockRequirement) items", systemImage: "lock.fill")
                            .font(.dynaPuff(11))
                            .foregroundStyle(deepGreen.opacity(0.8))
                    } else {
                        Text("💰 \(item.price)")
                            .font(.dynaPuff(13).weight(.medium))
                            .foregroundStyle(affordable ? Color.white : AppColor.mutedInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(affordable ? Color.orange : Color.black.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 30)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(tileColor(for: item, unlocked: unlocked, owned: owned))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func tileColor(for item: ShopAccessory, unlocked: Bool, owned: Bool) -> Color {
        guard unlocked || owned else {
            return AppColor.shopLockedTile
        }

        switch item.category {
        case .head: return AppColor.shopHeadTile
        case .face: return AppColor.shopFaceTile
        case .neck: return AppColor.shopNeckTile
        case .extra: return AppColor.shopExtraTile
        }
    }

    // MARK: My Munchkin

    private var munchkinSection: some View {
        VStack(spacing: 16) {
            munchkinPreview

            if ownedAccessories.isEmpty {
                VStack(spacing: 10) {
                    Text("🧺")
                        .font(.dynaPuff(44))

                    Text("No accessories yet")
                        .font(.dynaPuff(17))

                    Text("Head to Buy and grab something cute for your munchkin.")
                        .font(.dynaPuff(13))
                        .foregroundStyle(AppColor.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(AppColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(AccessoryCategory.allCases) { category in
                    let items = ownedAccessories.filter { $0.category == category }

                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(category.emoji) \(category.title)")
                                .font(.dynaPuff(17))

                            LazyVGrid(columns: inventoryColumns, spacing: 10) {
                                ForEach(items) { item in
                                    dressUpTile(item)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
    }

    private var munchkinPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Your Munchkin")
                    .font(.dynaPuff(17))

                Spacer()

                Text("\(ownedIDs.count)/\(ShopCatalogue.items.count) owned")
                    .font(.dynaPuff(13).weight(.semibold))
                    .foregroundStyle(deepGreen)
            }

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 200, height: 200)

                MunchkinAvatarView(size: 115)
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)

            Text(
                equippedAccessories.isEmpty
                    ? "Your munchkin is ready for a makeover!"
                    : "Tap to wear or remove. Touch and hold to sell."
            )
            .font(.dynaPuff(13))
            .foregroundStyle(deepGreen)
            .multilineTextAlignment(.center)

            if !equippedAccessories.isEmpty {
                Button {
                    equippedRaw = ""
                } label: {
                    Text("Take everything off")
                        .font(.dynaPuff(13).weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColor.buttonGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(mintColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func dressUpTile(_ item: ShopAccessory) -> some View {
        let isWearing = equipped[item.category] == item.id

        return Button {
            toggleEquip(item)
        } label: {
            VStack(spacing: 6) {
                Text(item.emoji)
                    .font(.dynaPuff(32))

                Text(item.name)
                    .font(.dynaPuff(11).weight(.semibold))
                    .foregroundStyle(isWearing ? Color.orange : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isWearing ? Color.orange.opacity(0.15) : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isWearing ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityValue(isWearing ? "Wearing" : "Not wearing")
        .contextMenu {
            Button(role: .destructive) {
                saleCandidate = item
            } label: {
                Label("Sell for 💰 \(item.sellValue)", systemImage: "minus.circle")
            }
        }
    }

    // MARK: Saved state

    private var ownedIDs: Set<String> {
        // Ignore ids for retired accessories so the "x/y owned" count and the
        // unlock thresholds always line up with the current catalogue.
        let known = Set(ShopCatalogue.items.map(\.id))
        let saved = Set(ownedRaw.split(separator: ",").map { String($0) })
        return saved.intersection(known)
    }

    private var equipped: [AccessoryCategory: String] {
        // Same decoder the avatar uses everywhere else in the app.
        MunchkinOutfit.decode(equippedRaw)
    }

    private var ownedAccessories: [ShopAccessory] {
        ShopCatalogue.items.filter { ownedIDs.contains($0.id) }
    }

    private var equippedAccessories: [ShopAccessory] {
        AccessoryCategory.allCases.compactMap { category -> ShopAccessory? in
            guard let id = equipped[category] else { return nil }
            return ShopCatalogue.items.first { $0.id == id }
        }
    }

    private func isUnlocked(_ item: ShopAccessory) -> Bool {
        item.unlockRequirement == 0 || ownedIDs.count >= item.unlockRequirement
    }

    private func buy(_ item: ShopAccessory) {
        guard !ownedIDs.contains(item.id),
              isUnlocked(item),
              coins >= item.price else { return }

        coins -= item.price

        var owned = ownedIDs
        owned.insert(item.id)
        ownedRaw = owned.sorted().joined(separator: ",")

        // Wear a new item straight away if that slot is still empty.
        if equipped[item.category] == nil {
            setEquipped(item.id, for: item.category)
        }
    }

    private func toggleEquip(_ item: ShopAccessory) {
        guard ownedIDs.contains(item.id) else { return }

        if equipped[item.category] == item.id {
            setEquipped(nil, for: item.category)
        } else {
            setEquipped(item.id, for: item.category)
        }
    }

    private func sell(_ item: ShopAccessory) {
        guard ownedIDs.contains(item.id) else { return }

        coins += item.sellValue

        var owned = ownedIDs
        owned.remove(item.id)
        ownedRaw = owned.sorted().joined(separator: ",")

        // Selling what you're wearing takes it off too.
        if equipped[item.category] == item.id {
            setEquipped(nil, for: item.category)
        }
    }

    private func setEquipped(_ id: String?, for category: AccessoryCategory) {
        var map = equipped
        map[category] = id
        equippedRaw = map
            .map { "\($0.key.rawValue)=\($0.value)" }
            .sorted()
            .joined(separator: ",")
    }
}

// MARK: - Item details

private struct AccessoryDetailSheet: View {
    let item: ShopAccessory
    let coins: Int
    let owned: Bool
    let wearing: Bool
    let unlocked: Bool
    let onBuy: () -> Void
    let onToggleWear: () -> Void
    let onSell: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSellConfirmation = false

    private let deepGreen = AppColor.greenInk
    private let cream = AppColor.background

    /// Locked accessories must stay a surprise, so none of their catalogue
    /// details are shown until the unlock requirement is met.
    private var revealed: Bool { unlocked || owned }

    var body: some View {
        VStack(spacing: 18) {
            Text(revealed ? item.emoji : "?")
                .font(.dynaPuff(76))
                .foregroundStyle(revealed ? Color.primary : deepGreen.opacity(0.6))
                .frame(width: 130, height: 130)
                .background(cream)
                .clipShape(Circle())

            VStack(spacing: 6) {
                Text(revealed ? item.name : "Mystery item")
                    .font(.dynaPuff(22))
                    .fontWeight(.bold)

                if revealed {
                    Text("\(item.category.emoji) \(item.category.title) accessory")
                        .font(.dynaPuff(13).weight(.semibold))
                        .foregroundStyle(deepGreen)

                    Text(item.about)
                        .font(.dynaPuff(15))
                        .foregroundStyle(AppColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                } else {
                    Text("A surprise for your Munchkin — keep collecting to find out what's inside!")
                        .font(.dynaPuff(15))
                        .foregroundStyle(AppColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }
            }

            Spacer(minLength: 0)

            actionButton
        }
        .padding(24)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        .alert("Sell \(item.name)?", isPresented: $showSellConfirmation) {
            Button("Sell for 💰 \(item.sellValue)", role: .destructive) {
                onSell()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You'll get 💰 \(item.sellValue) back. You can buy it again later.")
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if owned {
            VStack(spacing: 10) {
                Button {
                    onToggleWear()
                    dismiss()
                } label: {
                    Label(
                        wearing ? "Take it off" : "Wear it",
                        systemImage: wearing ? "xmark.circle" : "checkmark.circle.fill"
                    )
                    .font(.dynaPuff(17))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.white)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showSellConfirmation = true
                } label: {
                    Label("Sell for 💰 \(item.sellValue)", systemImage: "minus.circle")
                        .font(.dynaPuff(15).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.red)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        } else if !unlocked {
            Text("Own \(item.unlockRequirement) accessories to reveal this one.")
                .font(.dynaPuff(13))
                .foregroundStyle(AppColor.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            Button {
                onBuy()
                dismiss()
            } label: {
                Text(
                    coins >= item.price
                        ? "Buy for 💰 \(item.price)"
                        : "Not enough coins (💰 \(coins))"
                )
                .font(.dynaPuff(17))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Color.white)
                .background(coins >= item.price ? Color.orange : Color.black.opacity(0.2))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(coins < item.price)
        }
    }
}

#Preview {
    NavigationStack {
        ShopView()
    }
}
