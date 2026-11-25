import SwiftUI

struct GoalItem: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var target: Int
    var progress: Int
    var difficulty: String // Easy/Medium/Hard
    var createdAt: Date? = nil
    var completedAt: Date? = nil
    var rewardClaimed: Bool? = nil
}

struct CompletedGoalRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var difficulty: String
    var reward: Int
    var completedAt: Date
}

enum GoalReward {
    static func coins(for difficulty: String) -> Int {
        switch difficulty {
        case "Easy": return 10
        case "Medium": return 25
        case "Hard": return 50
        default: return 10
        }
    }
}

/// Shared by the Goals tab and the Home screen so a reward can only ever be
/// paid out once, no matter where it is claimed.
enum GoalClaim {
    static func claim(_ id: UUID) {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "goals_v1"),
              var goals = try? JSONDecoder().decode([GoalItem].self, from: data),
              let index = goals.firstIndex(where: { $0.id == id }),
              goals[index].completedAt != nil,
              goals[index].rewardClaimed != true else { return }

        let reward = GoalReward.coins(for: goals[index].difficulty)
        var history = defaults.data(forKey: "goal_history_v1")
            .flatMap { try? JSONDecoder().decode([CompletedGoalRecord].self, from: $0) } ?? []

        history.append(CompletedGoalRecord(
            title: goals[index].title,
            difficulty: goals[index].difficulty,
            reward: reward,
            completedAt: goals[index].completedAt ?? Date()
        ))
        goals[index].rewardClaimed = true

        if let goalData = try? JSONEncoder().encode(goals) {
            defaults.set(goalData, forKey: "goals_v1")
        }
        if let historyData = try? JSONEncoder().encode(history) {
            defaults.set(historyData, forKey: "goal_history_v1")
        }
        defaults.set(
            defaults.integer(forKey: "goal_currency_v1") + reward,
            forKey: "goal_currency_v1"
        )
    }
}

// MARK: - Data repairs

/// One-time fixes for goal data written by older builds.
enum GoalRewardRepair {
    /// Restores goals that an older build hid by matching on title alone.
    ///
    /// That check marked a freshly completed goal as "claimed" whenever the
    /// same title had ever been paid out before, so the goal disappeared from
    /// the Goals tab without any coins being awarded. A genuinely claimed goal
    /// has a history record with the same title *and* the same completion
    /// date, so anything else with a matching title goes back to unclaimed.
    static func runIfNeeded() {
        let repairKey = "goals_claim_repair_v1"
        guard !UserDefaults.standard.bool(forKey: repairKey) else { return }
        UserDefaults.standard.set(true, forKey: repairKey)

        guard let goalData = UserDefaults.standard.data(forKey: "goals_v1"),
              var goals = try? JSONDecoder().decode([GoalItem].self, from: goalData) else { return }

        let history = UserDefaults.standard.data(forKey: "goal_history_v1")
            .flatMap { try? JSONDecoder().decode([CompletedGoalRecord].self, from: $0) } ?? []

        var didRepair = false
        for index in goals.indices {
            guard let completedAt = goals[index].completedAt,
                  goals[index].rewardClaimed == true else { continue }

            let title = goals[index].title
            let hasOwnRecord = history.contains {
                $0.title == title && abs($0.completedAt.timeIntervalSince(completedAt)) < 2
            }
            let hasOtherRecord = history.contains { $0.title == title }

            if !hasOwnRecord && hasOtherRecord {
                goals[index].rewardClaimed = false
                didRepair = true
            }
        }

        if didRepair, let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: "goals_v1")
        }
    }
}

// Detects whether a goal is about eating out / trying new food places.
enum GoalKeywords {
    private static let foodKeywords = [
        "restaurant", "cuisine", "spot", "place", "eat", "food",
        "dish", "meal", "cafe", "dining", "bakery", "dessert"
    ]

    /// Largest target the app offers. Kept in step with the old stepper range so
    /// saved goals and their difficulty bands stay consistent.
    static let hardMaximumTarget = 50

    /// Controlled building blocks for the guided editor. Every noun contains a
    /// word the visit tracker recognises, so any combination is trackable.
    static let goalVerbs = ["Try", "Visit"]
    static let goalNouns = [
        "restaurants", "cuisines", "spots", "cafes", "places to eat", "desserts"
    ]

    private static let singularNouns: [String: String] = [
        "restaurant": "restaurants",
        "cuisine": "cuisines",
        "spot": "spots",
        "cafe": "cafes",
        "place to eat": "places to eat",
        "dessert": "desserts"
    ]

    /// Accepts the singular forms used by the older quick-add presets.
    static func canonicalNoun(_ value: String) -> String? {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if goalNouns.contains(key) { return key }
        return singularNouns[key]
    }

    static func isFoodRelated(_ title: String) -> Bool {
        let lowercased = title.lowercased()
        return foodKeywords.contains { lowercased.contains($0) }
    }

    /// Cuisine goals count distinct cuisine types, not restaurant visits.
    static func isCuisineRelated(_ title: String) -> Bool {
        title.lowercased().contains("cuisine")
    }

    /// Spots already spent on another quest can never pay this one.
    private static var restaurantsLeft: Int {
        let directoryIDs = Set(RestaurantDirectory.all.map(\.id))
        let used = Set(RestaurantGoalCredits.all().map(\.restaurantID))
            .intersection(directoryIDs)
        return max(0, directoryIDs.count - used.count)
    }

    /// Distinct cuisines no quest has claimed yet, including credits written
    /// by older builds that predate the cuisine key.
    private static var cuisinesLeft: Int {
        let directory = RestaurantDirectory.all
        let used = Set(RestaurantGoalCredits.all().compactMap { credit -> String? in
            if let cuisineKey = credit.cuisineKey {
                return RestaurantGoalCredits.normalized(cuisineKey)
            }
            return directory.first { $0.id == credit.restaurantID }
                .map { RestaurantGoalCredits.normalized($0.cuisine) }
        })
        return Set(directory.map { RestaurantGoalCredits.normalized($0.cuisine) })
            .filter { !used.contains($0) }.count
    }

    /// Highest target that can still be completed with the remaining spots.
    static func maximumTarget(for title: String) -> Int {
        let available = isCuisineRelated(title) ? cuisinesLeft : restaurantsLeft
        return min(hardMaximumTarget, available)
    }

    /// Nil means the goal can actually be completed by checking off visits.
    static func validationMessage(for title: String, target: Int) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Give your goal a short name." }

        guard isFoodRelated(trimmed) else {
            return "Include a food word such as restaurant, cuisine, spot, cafe or food so Munchkin can track it."
        }

        let cap = maximumTarget(for: trimmed)
        guard target <= cap else {
            let unit = isCuisineRelated(trimmed) ? "cuisines" : "restaurants"
            return "Only \(cap) \(unit) left to count — lower the target."
        }

        if let countInTitle = targetNumber(in: trimmed) {
            if countInTitle != target {
                return "The title says \(countInTitle) but Target is \(target) — make them match."
            }
        } else if hasOutOfRangeNumber(in: trimmed) {
            return "Use a number between 1 and \(hardMaximumTarget), or leave it out and set Target below."
        }
        return nil
    }

    private static func hasOutOfRangeNumber(in title: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d+\b"#) else { return false }
        return regex.matches(in: title, range: NSRange(title.startIndex..., in: title))
            .contains { match in
                guard let range = Range(match.range, in: title),
                      let value = Int(title[range]) else { return false }
                return !(1...hardMaximumTarget).contains(value)
            }
    }

    /// Reads a count from a goal title, e.g. "Try 5 new restaurants" -> 5.
    /// Both digits and written numbers are understood. Only counts in the
    /// app's target range are returned so stray numbers are ignored.
    static func targetNumber(in title: String) -> Int? {
        let text = title.lowercased()

        if let match = text.range(of: #"\b\d{1,2}\b"#, options: .regularExpression),
           let value = Int(text[match]),
           (1...50).contains(value) {
            return value
        }

        let numberWords: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
            "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18,
            "nineteen": 19, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50
        ]
        for (word, value) in numberWords where text.contains(word) {
            return value
        }
        return nil
    }
}

struct GoalsView: View {
    @State private var goals: [GoalItem] = []
    @State private var history: [CompletedGoalRecord] = []
    @State private var currency: Int = 0
    @State private var claimPulse = 0
    @State private var lastClaimGain = 0

    @State private var editor: GoalEditor?
    @State private var clearPrompt: ClearPrompt?

    private let backgroundColor = AppColor.background
    private let cardColor = AppColor.card

    /// Completed goals that still owe coins. Kept at the top of the list so
    /// they are impossible to miss.
    private var claimableGoals: [GoalItem] {
        goals.filter { $0.completedAt != nil && $0.rewardClaimed != true }
    }

    private var activeGoals: [GoalItem] {
        goals.filter { $0.completedAt == nil && $0.rewardClaimed != true }
    }

    private var sortedHistory: [CompletedGoalRecord] {
        history.sorted { $0.completedAt > $1.completedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                // Completed goals waiting for their coins
                if !claimableGoals.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.green)

                        Text("Ready to Claim")
                            .font(.dynaPuff(22))
                            .fontWeight(.semibold)
                    }
                    .rowStyling(top: 12, bottom: 0)

                    // Completed goals are locked: only the claim action is
                    // available, so their earned reward cannot be altered.
                    ForEach(claimableGoals) { g in
                        goalRow(g)
                            .rowStyling()
                    }
                }

                // Active goals
                HStack(alignment: .firstTextBaseline) {
                    Text("Active Goals")
                        .font(.dynaPuff(22))
                        .fontWeight(.medium)

                    Spacer()

                    if !activeGoals.isEmpty {
                        Button("Clear") {
                            clearPrompt = .active
                        }
                        .buttonStyle(.plain)
                        .font(.dynaPuff(15).weight(.semibold))
                        .foregroundStyle(.orange)
                        // Keep the tap target to the word "Clear" only, so
                        // tapping the section title does not prompt to clear.
                        .contentShape(Rectangle())
                    }
                }
                .rowStyling(top: 12, bottom: 0)

                if activeGoals.isEmpty {
                    Text(
                        claimableGoals.isEmpty
                            ? "No active goals. Add one below."
                            : "Nothing in progress. Add another goal below."
                    )
                    .foregroundStyle(AppColor.secondaryText)
                    .rowStyling()
                } else {
                    ForEach(activeGoals) { g in
                        goalRow(g)
                            .rowStyling()
                            .swipeActions(edge: .leading) {
                                editSwipe(for: g)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                deleteSwipe(for: g)
                            }
                    }
                }

                // Quick add
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick add")
                        .font(.dynaPuff(15))
                        .foregroundStyle(AppColor.secondaryText)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("Try 3 new restaurants") { presetGoal(title: "Try 3 new restaurants", target: 3) }
                            Button("Explore 2 new cuisines") { presetGoal(title: "Explore 2 new cuisines", target: 2) }
                            Button("Visit 1 new spot") { presetGoal(title: "Visit 1 new spot", target: 1) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                .rowStyling(top: 12)

                Button {
                    editor = .new()
                } label: {
                    Label("Add Custom Goal", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .rowStyling()

                Divider()
                    .rowStyling(top: 12, bottom: 4)

                // History
                HStack(alignment: .firstTextBaseline) {
                    Text("History")
                        .font(.dynaPuff(22))
                        .fontWeight(.medium)

                    Spacer()

                    if !history.isEmpty {
                        Button("Clear") {
                            clearPrompt = .history
                        }
                        .buttonStyle(.plain)
                        .font(.dynaPuff(15).weight(.semibold))
                        .foregroundStyle(.orange)
                        .contentShape(Rectangle())
                    }
                }
                .rowStyling(top: 8, bottom: 0)

                if history.isEmpty {
                    Text("No completed goals yet.")
                        .foregroundStyle(AppColor.secondaryText)
                        .rowStyling()
                } else {
                    ForEach(sortedHistory) { h in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(h.title).fontWeight(.medium)
                                Text("\(h.difficulty) • \(h.completedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.dynaPuff(13))
                                    .foregroundStyle(AppColor.secondaryText)
                            }
                            Spacer()
                            Text("+💰\(h.reward)")
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .rowStyling()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteHistory(h.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
            .navigationTitle("Goals")
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
            .onAppear(perform: load)
            .fullScreenCover(item: $clearPrompt) { prompt in
                ClearConfirmationView(
                    prompt: prompt,
                    onConfirm: {
                        switch prompt {
                        case .history:
                            clearAllHistory()
                        case .active:
                            clearActiveGoals()
                        }
                        clearPrompt = nil
                    },
                    onCancel: {
                        clearPrompt = nil
                    }
                )
            }
            .sheet(item: $editor) { editor in
                GoalEditorView(editor: editor) { saved in
                    if editor.isNew {
                        goals.append(saved)
                    } else if let index = goals.firstIndex(where: { $0.id == saved.id }) {
                        goals[index] = saved
                    }
                    save()
                }
            }
        }
    }

    private func goalRow(_ g: GoalItem) -> some View {
        let isCompleted = g.completedAt != nil
        let isReadyToClaim = isCompleted && g.rewardClaimed != true

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(g.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if isCompleted {
                    Image(systemName: "flag.checkered")
                        .font(.dynaPuff(13))
                        .foregroundStyle(.green)
                }

                Spacer(minLength: 8)

                Text("\(g.progress)/\(g.target)")
                    .font(.dynaPuff(13))
                    .foregroundStyle(AppColor.secondaryText)

                Text(g.difficulty)
                    .font(.dynaPuff(13))
                    .foregroundStyle(.orange)
            }

            ProgressView(value: Double(g.progress), total: Double(max(g.target, 1)))
                .tint(isCompleted ? .green : .orange)
                .frame(maxWidth: .infinity)

            if isReadyToClaim {
                Button {
                    claimReward(g)
                } label: {
                    Label("Claim +💰\(GoalReward.coins(for: g.difficulty))", systemImage: "gift.fill")
                        .font(.dynaPuff(15).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(14)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func presetGoal(title: String, target: Int) {
        // Even the quick-add goals must fit what is left to count.
        let safeTarget = max(1, min(target, GoalKeywords.maximumTarget(for: title)))
        goals.append(GoalItem(
            title: title,
            target: safeTarget,
            progress: 0,
            difficulty: suggestedDifficulty(for: safeTarget)
        ))
        save()
    }

    func openEditor(for goal: GoalItem) {
        guard goal.completedAt == nil else { return }
        editor = GoalEditor(goal: goal, isNew: false)
    }

    @ViewBuilder
    func editSwipe(for goal: GoalItem) -> some View {
        Button {
            openEditor(for: goal)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.orange)
    }

    @ViewBuilder
    func deleteSwipe(for goal: GoalItem) -> some View {
        Button(role: .destructive) {
            deleteGoal(goal.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    func clearActiveGoals() {
        goals.removeAll { $0.completedAt == nil }
        save()
    }

    func deleteGoal(_ id: UUID) {
        guard let goal = goals.first(where: { $0.id == id }),
              goal.completedAt == nil
        else { return }
        goals.removeAll { $0.id == id }
        save()
    }

    func deleteHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
        save()
    }

    func claimReward(_ goal: GoalItem) {
        let reward = GoalReward.coins(for: goal.difficulty)
        GoalClaim.claim(goal.id)
        load()
        lastClaimGain = reward
        claimPulse += 1
    }

    func load() {
        // Run before decoding so the list reflects any repaired state.
        GoalRewardRepair.runIfNeeded()

        if let data = UserDefaults.standard.data(forKey: "goals_v1"),
           let decoded = try? JSONDecoder().decode([GoalItem].self, from: data) {
            goals = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "goal_history_v1"),
           let decoded = try? JSONDecoder().decode([CompletedGoalRecord].self, from: data) {
            history = decoded
        }
        currency = UserDefaults.standard.integer(forKey: "goal_currency_v1")

        // Goals completed by very old builds may already have been paid out.
        // Only treat one as paid if history has a record for the same title at
        // the same completion time; title alone is not proof (that was the bug
        // that hid freshly completed goals).
        var didMigrate = false
        for index in goals.indices where goals[index].completedAt != nil && goals[index].rewardClaimed == nil {
            guard let completedAt = goals[index].completedAt else { continue }
            let title = goals[index].title
            let wasPaid = history.contains {
                $0.title == title && abs($0.completedAt.timeIntervalSince(completedAt)) < 2
            }
            if wasPaid {
                goals[index].rewardClaimed = true
                didMigrate = true
            }
        }
        if didMigrate {
            save()
        }
    }

    /// Wipes the whole history in one tap. Goals that still say
    /// rewardClaimed != true stay claimable, so clearing the log can never
    /// swallow a reward the user has not collected yet.
    func clearAllHistory() {
        history = []
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: "goals_v1")
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "goal_history_v1")
        }
        UserDefaults.standard.set(currency, forKey: "goal_currency_v1")
    }
}

/// Payload for the shared add/edit goal sheet.
struct GoalEditor: Identifiable {
    let id = UUID()
    let goal: GoalItem
    let isNew: Bool

    static func new() -> GoalEditor {
        GoalEditor(
            goal: GoalItem(
                title: "",
                target: 1,
                progress: 0,
                difficulty: suggestedDifficulty(for: 1)
            ),
            isNew: true
        )
    }
}

/// A goal assembled from controlled parts. The noun always carries a
/// recognised keyword, so every title this produces is completable.
private struct GoalTemplate {
    var verb: String
    var count: Int
    var noun: String

    var title: String { "\(verb) \(count) new \(noun)" }

    /// Recognises goals created from the presets so editing one keeps its
    /// guided layout instead of dropping back to free text.
    static func parse(_ title: String) -> GoalTemplate? {
        let pattern = #"^\s*(try|explore|visit)\s+(\d{1,2})\s+new\s+(.+?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                  in: title,
                  range: NSRange(title.startIndex..., in: title)
              ),
              match.numberOfRanges == 4,
              let verbRange = Range(match.range(at: 1), in: title),
              let countRange = Range(match.range(at: 2), in: title),
              let nounRange = Range(match.range(at: 3), in: title),
              let count = Int(title[countRange]),
              let noun = GoalKeywords.canonicalNoun(String(title[nounRange]))
        else { return nil }

        let rawVerb = String(title[verbRange])
        let verb = GoalKeywords.goalVerbs.first {
            $0.caseInsensitiveCompare(rawVerb) == .orderedSame
        } ?? "Try"
        return GoalTemplate(verb: verb, count: count, noun: noun)
    }
}

private func suggestedDifficulty(for target: Int) -> String {
    switch target {
    case ...1: return "Easy"
    case 2...3: return "Medium"
    default: return "Hard"
    }
}

/// Form used for both creating a goal and editing an existing one.
private struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let editor: GoalEditor
    let onSave: (GoalItem) -> Void

    @State private var title: String
    @State private var target: Int
    @State private var useTemplate: Bool
    @State private var verb: String
    @State private var noun: String

    init(editor: GoalEditor, onSave: @escaping (GoalItem) -> Void) {
        self.editor = editor
        self.onSave = onSave

        let parsed = GoalTemplate.parse(editor.goal.title)
        _title = State(initialValue: editor.goal.title)
        _target = State(initialValue: editor.goal.target)
        // New goals always start guided. Existing titles that already fit the
        // pattern stay guided too; anything else keeps its text so it can be
        // repaired using the inline validation below.
        _useTemplate = State(initialValue: editor.isNew || parsed != nil)
        _verb = State(initialValue: parsed?.verb ?? "Try")
        _noun = State(initialValue: parsed?.noun ?? "restaurants")
    }

    /// The title that will be saved, from whichever mode is active.
    private var effectiveTitle: String {
        useTemplate ? "\(verb) \(target) new \(noun)" : title
    }

    private var validationMessage: String? {
        GoalKeywords.validationMessage(for: effectiveTitle, target: target)
    }

    private var canSave: Bool { validationMessage == nil }

    /// Difficulty is derived from the target, never chosen by the user.
    private var difficulty: String {
        suggestedDifficulty(for: target)
    }

    /// Moving the target cannot drop below progress already made.
    private var minTarget: Int {
        max(1, editor.goal.progress)
    }

    /// Targets above the remaining spots can never be completed.
    private var maxTarget: Int {
        max(minTarget, GoalKeywords.maximumTarget(for: effectiveTitle))
    }

    /// Typed number plus tap controls, used in both goal editor modes.
    private func targetInput(_ label: String) -> some View {
        HStack(spacing: 12) {
            Text(label)

            Spacer()

            Button {
                target = max(minTarget, target - 1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.dynaPuff(22))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .disabled(target <= minTarget)
            .accessibilityLabel("Decrease \(label.lowercased())")

            TextField("", value: $target, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .textFieldStyle(.roundedBorder)
                .onSubmit { target = max(minTarget, target) }
                .accessibilityLabel(label)

            Button {
                target = min(maxTarget, target + 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.dynaPuff(22))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .disabled(target >= maxTarget)
            .accessibilityLabel("Increase \(label.lowercased())")
        }
        .onChange(of: target) { _, newValue in
            // Only cap the upper bound while typing, so a value like "10" can
            // be entered one digit at a time. The lower bound is applied when
            // the field is submitted or the goal is saved.
            let cap = min(newValue, maxTarget)
            if cap != newValue {
                target = cap
            }
            // Keep a custom title's number in sync with the typed target.
            if !useTemplate,
               let template = GoalTemplate.parse(title),
               GoalKeywords.targetNumber(in: title) != cap {
                title = "\(template.verb) \(cap) new \(template.noun)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    if useTemplate {
                        Picker("Start with", selection: $verb) {
                            ForEach(GoalKeywords.goalVerbs, id: \.self) { word in
                                Text(word).tag(word)
                            }
                        }
                        targetInput("How many")
                        Picker("Kind of place", selection: $noun) {
                            ForEach(GoalKeywords.goalNouns, id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                        .onChange(of: noun) { _, newValue in
                            clampTarget(verb: verb, noun: newValue)
                        }

                        Text(effectiveTitle)
                            .font(.dynaPuff(17).weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    } else {
                        TextField("Goal title", text: $title)
                            .onChange(of: title) { _, newTitle in
                                if let detected = GoalKeywords.targetNumber(in: newTitle) {
                                    // A number in the title sets the target, and
                                    // difficulty follows from it automatically.
                                    target = max(detected, minTarget)
                                }
                            }

                        targetInput("Target")
                    }

                    LabeledContent("Difficulty", value: difficulty)
                        .foregroundStyle(AppColor.secondaryText)

                    if let message = validationMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.dynaPuff(13))
                            .foregroundStyle(.orange)
                    } else {
                        Label(
                            "Looks good — Munchkin can track this goal.",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.dynaPuff(13))
                        .foregroundStyle(.green)
                    }

                    Button(useTemplate ? "Write a custom title instead" : "Use the guided format") {
                        switchMode()
                    }
                    .font(.dynaPuff(13))
                }

                Section {
                    Label(
                        "Reward: +💰\(GoalReward.coins(for: difficulty))",
                        systemImage: "gift.fill"
                    )
                    .foregroundStyle(.orange)

                    if !editor.isNew {
                        LabeledContent("Progress", value: "\(editor.goal.progress)/\(target)")
                            .foregroundStyle(AppColor.secondaryText)
                    }

                    if GoalKeywords.isFoodRelated(effectiveTitle) {
                        Label(
                            "This goal also updates when you mark a restaurant as visited.",
                            systemImage: "fork.knife"
                        )
                        .font(.dynaPuff(13))
                        .foregroundStyle(AppColor.secondaryText)
                    }

                    if GoalKeywords.isCuisineRelated(effectiveTitle) {
                        Label(
                            "Cuisine goals need a different cuisine each time.",
                            systemImage: "fork.knife"
                        )
                        .font(.dynaPuff(13))
                        .foregroundStyle(AppColor.secondaryText)
                    }
                }
            }
            .navigationTitle(editor.isNew ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.orange)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editor.isNew ? "Add" : "Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    /// Switching to a cuisine goal can lower the ceiling below the current
    /// count, so pull it back into the selectable range.
    private func clampTarget(verb newVerb: String, noun newNoun: String) {
        let cap = max(
            minTarget,
            GoalKeywords.maximumTarget(for: "\(newVerb) \(target) new \(newNoun)")
        )
        if target > cap { target = cap }
    }

    private func switchMode() {
        if useTemplate {
            title = effectiveTitle
            useTemplate = false
            return
        }

        let parsed = GoalTemplate.parse(title)
        let newVerb = parsed?.verb ?? "Try"
        let newNoun = parsed?.noun ?? "restaurants"
        let newCount = parsed?.count ?? target
        let cap = max(
            minTarget,
            GoalKeywords.maximumTarget(for: "\(newVerb) \(newCount) new \(newNoun)")
        )
        verb = newVerb
        noun = newNoun
        target = min(newCount, cap)
        useTemplate = true
    }

    private func save() {
        target = min(max(target, minTarget), maxTarget)
        guard canSave else { return }

        var updated = editor.goal
        updated.title = effectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.target = target
        updated.difficulty = difficulty
        // Progress, completion date and claim state are intentionally left
        // untouched: those are earned, not edited.

        onSave(updated)
        dismiss()
    }
}

/// Which list a full-screen clear confirmation is asking about.
enum ClearPrompt: String, Identifiable {
    case history
    case active

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "Clear history?"
        case .active: return "Clear active goals?"
        }
    }

    var message: String {
        switch self {
        case .history:
            return "This removes completed goal records. Your coins and active goals stay as they are."
        case .active:
            return "This removes the goals you're still working on. Completed goals waiting to be claimed, your coins and your history stay."
        }
    }

    var icon: String {
        switch self {
        case .history: return "clock.arrow.circlepath"
        case .active: return "checklist.unchecked"
        }
    }

    var confirmTitle: String {
        switch self {
        case .history: return "Clear History"
        case .active: return "Clear Active Goals"
        }
    }
}

/// Full-screen confirmation so the warning is impossible to miss instead of
/// tucked into a bottom action sheet.
private struct ClearConfirmationView: View {
    let prompt: ClearPrompt
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let backgroundColor = AppColor.background

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: prompt.icon)
                    .font(.dynaPuff(56).weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 118, height: 118)
                    .background(Circle().fill(Color.orange.opacity(0.15)))

                Text(prompt.title)
                    .font(.dynaPuff(28).weight(.bold))
                    .multilineTextAlignment(.center)

                Text(prompt.message)
                    .font(.dynaPuff(17))
                    .foregroundStyle(AppColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        onConfirm()
                    } label: {
                        Text(prompt.confirmTitle)
                            .font(.dynaPuff(17))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(Color.white)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.dynaPuff(17))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.orange)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
        }
    }
}

private extension View {
    func rowStyling(top: CGFloat = 4, bottom: CGFloat = 4) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
    }
}
