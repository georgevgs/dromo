import Foundation

/// Plans in and out of Dromo as JSON a chat assistant can write (the format `PlanFormat.prompt` teaches):
/// "90 sec", "600 m" and "5:10–5:20" rather than the app's own storage format.
///
/// Reading is strict about names — an unknown key is reported, never skipped, so a typo can't quietly drop
/// a pace alert — but easy-going about how values are written ("90s", "1:30", "0.6 km", "5:10-5:20/km").
/// Every problem is collected, so they can all be fixed in one go.
enum PlanFile {
    struct Problems: Error, Equatable {
        var messages: [String]
    }

    static func read(_ text: String) throws(Problems) -> TrainingPlan {
        guard let object = jsonObject(in: text) else {
            throw Problems(messages: ["This isn't a plan Dromo can read. Copy the whole JSON reply, from the first { to the last }."])
        }
        var reader = Reader()
        let plan = reader.plan(object)
        if let plan, reader.problems.isEmpty {
            return plan
        }
        throw Problems(messages: reader.problems)
    }

    static func write(_ plan: TrainingPlan) -> String {
        // Only text, numbers, true and lists, so it's always valid JSON. Sorted keys keep the output the same every time.
        let data = try! JSONSerialization.data(
            withJSONObject: Writer.plan(plan),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    /// Session IDs come from the date and the order within the day: the same day always gets the same ID,
    /// so a re-imported plan still matches what's on the Watch and keeps what's done.
    static func workoutID(_ date: PlanDate, slot: Int) -> UUID {
        UUID(uuidString: String(format: "5B250000-0000-0000-0000-%04d%02d%02d%04d", date.year, date.month, date.day, slot))!
    }

    static func weekID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "5B250000-0000-0000-0001-%012d", number))!
    }

    /// The JSON object in a pasted reply, ignoring any words or code fences around it.
    private static func jsonObject(in text: String) -> [String: Any]? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        let json = String(text[start...end])
        if let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] {
            return object
        }
        // Text copied from a chat bubble rather than a code block can come with curly quotes.
        let straightened = json.replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
        return try? JSONSerialization.jsonObject(with: Data(straightened.utf8)) as? [String: Any]
    }
}

// MARK: - Reading

private struct Reader {
    private(set) var problems: [String] = []

    private static let stepKinds: [String: WorkoutSegment.Kind] = [
        "warmup": .warmup, "easy": .easy, "work": .work, "stride": .stride,
        "recovery": .recovery, "cooldown": .cooldown, "race": .race,
    ]

    mutating func plan(_ object: [String: Any]) -> TrainingPlan? {
        let place = "Plan"
        allow(["dromo", "title", "race", "weeks"], in: object, at: place)
        if let version = object["dromo"], wholeNumber(version) != 1 {
            report("Dromo reads version 1 plans. Set \"dromo\": 1.", at: place)
        }
        let title = string(object["title"], "title", at: place)
        var race: Race?
        if let value = object["race"] {
            race = self.race(value)
        }

        guard let weekObjects = list(object["weeks"], "weeks", at: place) else { return nil }
        var weeks: [TrainingWeek] = []
        for (index, value) in weekObjects.enumerated() {
            if let week = week(value, number: index + 1) {
                weeks.append(week)
            }
        }
        guard let title, weeks.count == weekObjects.count else { return nil }

        // Number sessions within each day in plan order, then give each its date-based ID.
        var slots: [PlanDate: Int] = [:]
        for week in weeks.indices {
            for session in weeks[week].workouts.indices {
                let date = weeks[week].workouts[session].date
                let slot = slots[date, default: 0]
                weeks[week].workouts[session].id = PlanFile.workoutID(date, slot: slot)
                slots[date] = slot + 1
            }
        }
        return TrainingPlan(title: title, race: race, weeks: weeks)
    }

    private mutating func race(_ value: Any) -> Race? {
        let place = "Race"
        guard let object = object(value, "race", at: place) else { return nil }
        allow(["name", "date", "distance", "goal"], in: object, at: place)
        let name = string(object["name"], "name", at: place)

        var date: PlanDate?
        if let text = string(object["date"], "date", at: place) {
            date = self.date(text, at: place)
        }

        var distance: Int?
        if let text = string(object["distance"], "distance", at: place) {
            if case .distance(let meters)? = Parse.goal(text) {
                distance = meters
            } else {
                report("“\(text)” isn't a distance. Write it like 5 km or 10 km.", at: place)
            }
        }

        var goal: Int?
        if let text = string(object["goal"], "goal", at: place, required: false) {
            goal = Parse.clock(text)
            if goal == nil {
                report("“\(text)” isn't a finish time. Write it like 24:59 or 1:45:00.", at: place)
            }
        }

        guard let name, let date, let distance else { return nil }
        return Race(name: name, date: date, distanceMeters: distance, goalTimeSeconds: goal)
    }

    private mutating func week(_ value: Any, number: Int) -> TrainingWeek? {
        let place = "Week \(number)"
        guard let object = object(value, "week", at: place) else { return nil }
        allow(["title", "sessions"], in: object, at: place)
        let title = string(object["title"], "title", at: place)
        guard let sessionObjects = list(object["sessions"], "sessions", at: place) else { return nil }
        var workouts: [PlannedWorkout] = []
        for (index, value) in sessionObjects.enumerated() {
            if let workout = session(value, week: place, number: index + 1) {
                workouts.append(workout)
            }
        }
        guard let title, workouts.count == sessionObjects.count else { return nil }
        workouts.sort { $0.date < $1.date }
        return TrainingWeek(id: PlanFile.weekID(number), title: title, workouts: workouts)
    }

    private mutating func session(_ value: Any, week: String, number: Int) -> PlannedWorkout? {
        // Until its date is known, a session goes by its position: "Week 2, session 3".
        let position = "\(week), session \(number)"
        guard let object = object(value, "session", at: position) else { return nil }
        allow(["date", "title", "start", "notes", "checkpoint", "warmup", "blocks", "cooldown"], in: object, at: position)
        guard let dateText = string(object["date"], "date", at: position), let date = date(dateText, at: position) else { return nil }

        // From here on it goes by its day: "Week 2 · Thu 8 Oct".
        let place = "\(week) · \(date.shortText)"
        let title = string(object["title"], "title", at: place)
        let notes = string(object["notes"], "notes", at: place, required: false)

        var startTime: PlanTime?
        if let text = string(object["start"], "start", at: place, required: false) {
            startTime = Parse.timeOfDay(text)
            if startTime == nil {
                report("“\(text)” isn't a start time. Write it like 09:00 or 17:30.", at: place)
            }
        }

        var isCheckpoint = false
        if let value = object["checkpoint"] {
            if let flag = bool(value) {
                isCheckpoint = flag
            } else {
                report("\"checkpoint\" is true or false.", at: place)
            }
        }

        var warmup: WorkoutSegment?
        if let value = object["warmup"] {
            warmup = edge(value, kind: .warmup, at: place)
        }
        var cooldown: WorkoutSegment?
        if let value = object["cooldown"] {
            cooldown = edge(value, kind: .cooldown, at: place)
        }

        var blocks: [SegmentBlock] = []
        if let blockObjects = list(object["blocks"], "blocks", at: place) {
            for (index, value) in blockObjects.enumerated() {
                // Name the block only when there's more than one to tell apart.
                var blockPlace = place
                if blockObjects.count > 1 {
                    blockPlace += ", block \(index + 1)"
                }
                if let block = block(value, at: blockPlace) {
                    blocks.append(block)
                }
            }
        }

        guard let title, !blocks.isEmpty else { return nil }
        return PlannedWorkout(
            id: UUID(),  // Replaced by the date-based ID once the whole plan is read.
            date: date,
            startTime: startTime,
            title: title,
            notes: notes,
            isCheckpoint: isCheckpoint,
            warmup: warmup,
            blocks: blocks,
            cooldown: cooldown
        )
    }

    /// A warm-up or cool-down: just its length ("10 min"), or a step object when it has a pace or label.
    private mutating func edge(_ value: Any, kind: WorkoutSegment.Kind, at place: String) -> WorkoutSegment? {
        if let text = value as? String {
            guard let goal = goal(text, at: place) else { return nil }
            return WorkoutSegment(kind: kind, goal: goal)
        }
        guard let step = step(value, at: place) else { return nil }
        if step.kind != kind {
            report("\"\(kind.rawValue)\" holds a \(kind.rawValue) step, like \"10 min\".", at: place)
            return nil
        }
        return step
    }

    private mutating func block(_ value: Any, at place: String) -> SegmentBlock? {
        guard let object = object(value, "block", at: place) else { return nil }
        allow(["repeat", "steps"], in: object, at: place)

        var repeats = 1
        if let value = object["repeat"] {
            if let number = wholeNumber(value), (1...50).contains(number) {
                repeats = number
            } else {
                report("\"repeat\" is a whole number from 1 to 50.", at: place)
            }
        }

        guard let stepObjects = list(object["steps"], "steps", at: place) else { return nil }
        var segments: [WorkoutSegment] = []
        for value in stepObjects {
            guard let segment = step(value, at: place) else {
                continue
            }
            if segment.kind == .warmup || segment.kind == .cooldown {
                report("A \(segment.kind.rawValue) goes in the session's \"\(segment.kind.rawValue)\", not in a block.", at: place)
                continue
            }
            segments.append(segment)
        }
        guard segments.count == stepObjects.count else { return nil }
        return SegmentBlock(repeats: repeats, segments: segments)
    }

    private mutating func step(_ value: Any, at place: String) -> WorkoutSegment? {
        guard let object = object(value, "step", at: place) else { return nil }
        let kindKeys = object.keys.filter { Self.stepKinds[$0] != nil }
        guard kindKeys.count == 1, let key = kindKeys.first, let kind = Self.stepKinds[key] else {
            report("Each step names one kind with its length, like {\"work\": \"90 sec\"}: warmup, easy, work, stride, recovery, cooldown or race.", at: place)
            return nil
        }
        allow([key, "pace", "label"], in: object, at: place)
        guard let goalText = string(object[key], key, at: place), let goal = goal(goalText, at: place) else { return nil }

        var pace: PaceRange?
        if let text = string(object["pace"], "pace", at: place, required: false) {
            pace = Parse.pace(text)
            if pace == nil {
                report("“\(text)” isn't a pace. Write it per kilometre, like 5:10–5:20 or 5:00.", at: place)
                return nil
            }
        }
        if kind.enforcesPace && pace == nil {
            report("\(key) steps need a pace, like \"pace\": \"5:10–5:20\". It becomes the Watch pace alert.", at: place)
            return nil
        }

        let label = string(object["label"], "label", at: place, required: false)
        return WorkoutSegment(kind: kind, goal: goal, pace: pace, label: label)
    }

    // MARK: Values

    private mutating func goal(_ text: String, at place: String) -> SegmentGoal? {
        if let goal = Parse.goal(text) {
            return goal
        }
        report("“\(text)” isn't a length. Write a time like 90 sec, 1:30 or 10 min, a distance like 400 m or 1 km, or open.", at: place)
        return nil
    }

    private mutating func date(_ text: String, at place: String) -> PlanDate? {
        if let date = Parse.date(text) {
            return date
        }
        report("“\(text)” isn't a date. Write it like 2026-10-08.", at: place)
        return nil
    }

    private mutating func string(_ value: Any?, _ key: String, at place: String, required: Bool = true) -> String? {
        guard let value else {
            if required {
                report("Missing \"\(key)\".", at: place)
            }
            return nil
        }
        let text = (value as? String)?.trimmingCharacters(in: .whitespaces)
        guard let text, !text.isEmpty else {
            report("\"\(key)\" should be text in quotes.", at: place)
            return nil
        }
        return text
    }

    private mutating func object(_ value: Any, _ name: String, at place: String) -> [String: Any]? {
        if let object = value as? [String: Any] {
            return object
        }
        report("Each \(name) should be an object in { }.", at: place)
        return nil
    }

    /// A list with at least one item in it.
    private mutating func list(_ value: Any?, _ key: String, at place: String) -> [Any]? {
        guard let value else {
            report("Missing \"\(key)\".", at: place)
            return nil
        }
        guard let items = value as? [Any], !items.isEmpty else {
            report("\"\(key)\" should be a list in [ ] with at least one item.", at: place)
            return nil
        }
        return items
    }

    private mutating func allow(_ keys: Set<String>, in object: [String: Any], at place: String) {
        let allowed = keys.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
        for key in object.keys.sorted() where !keys.contains(key) {
            report("Dromo doesn't read \"\(key)\" here. It reads \(allowed).", at: place)
        }
    }

    private mutating func report(_ message: String, at place: String) {
        problems.append("\(place): \(message)")
    }

    // JSON numbers and booleans both arrive as NSNumber, so true would otherwise pass for 1.

    private func bool(_ value: Any) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private func wholeNumber(_ value: Any) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return value as? Int
    }
}

/// The value formats, shared by reading and the tests.
enum Parse {
    /// "90 sec", "90s", "1:30", "10 min", "1 h", "1:05:00", "600 m", "1 km", "1.5 km", "5K" or "open".
    static func goal(_ text: String) -> SegmentGoal? {
        let text = text.lowercased().trimmingCharacters(in: .whitespaces)
        if text == "open" {
            return .open
        }
        if text.contains(":") {
            // "1:30" or "1:30 min": minutes and seconds either way.
            let digits = text.replacing(/\s*[a-z]+$/, with: "")
            guard let seconds = clock(digits), seconds > 0 else { return nil }
            return .time(seconds: seconds)
        }

        // A number and a unit: "90 sec", "0.6 km", "1,5 km".
        guard let match = text.wholeMatch(of: /(\d+(?:[.,]\d+)?)\s*([a-z]+)/),
              let number = Double(match.1.replacingOccurrences(of: ",", with: ".")),
              number > 0
        else {
            return nil
        }
        switch match.2 {
        case "s", "sec", "secs", "second", "seconds":
            return wholeSeconds(number)
        case "min", "mins", "minute", "minutes":
            return wholeSeconds(number * 60)
        case "h", "hr", "hrs", "hour", "hours":
            return wholeSeconds(number * 3600)
        case "m", "meter", "meters", "metre", "metres":
            return .distance(meters: Int(number.rounded()))
        case "k", "km", "kms", "kilometer", "kilometers", "kilometre", "kilometres":
            return .distance(meters: Int((number * 1000).rounded()))
        default:
            return nil
        }
    }

    /// "1:30" (minutes and seconds) or "1:05:00" (hours too), in seconds.
    static func clock(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        var seconds = 0
        for (index, part) in parts.enumerated() {
            guard let number = Int(part), number >= 0 else { return nil }
            // After the first part, each is two digits under 60: "1:05", not "1:5" or "1:75".
            if index > 0 && (part.count != 2 || number >= 60) {
                return nil
            }
            seconds = seconds * 60 + number
        }
        return seconds
    }

    /// "5:10–5:20", "5:10-5:20/km", "5:10 to 5:20" or "5:00", per kilometre, in either order.
    static func pace(_ text: String) -> PaceRange? {
        var text = text.lowercased()
        for unit in ["min/km", "/km", "per km"] {
            text = text.replacingOccurrences(of: unit, with: "")
        }
        var ends: [Int] = []
        for end in text.split(separator: /\s*(?:–|—|-|to)\s*/) {
            // Minutes and seconds only, between 2:00 and 15:00 a kilometre.
            guard end.filter({ $0 == ":" }).count == 1, let seconds = clock(String(end)), (120...900).contains(seconds) else { return nil }
            ends.append(seconds)
        }
        guard ends.count <= 2, let fastest = ends.min(), let slowest = ends.max() else { return nil }
        return PaceRange(fastest: fastest, slowest: slowest)
    }

    /// "2026-10-08", checked against the calendar so 30 February is caught.
    static func date(_ text: String) -> PlanDate? {
        guard let match = text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
              let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
        else {
            return nil
        }
        let date = PlanDate(year, month, day)
        // The calendar rolls 30 February over into March, so a date that comes back different wasn't a real one.
        guard let real = Calendar.plan.date(from: DateComponents(year: year, month: month, day: day)), PlanDate(real) == date else { return nil }
        return date
    }

    /// "17:00" or "9:30".
    static func timeOfDay(_ text: String) -> PlanTime? {
        guard let match = text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /(\d{1,2}):(\d{2})/),
              let hour = Int(match.1), let minute = Int(match.2),
              hour < 24, minute < 60
        else {
            return nil
        }
        return PlanTime(hour: hour, minute: minute)
    }

    /// Whole seconds only: "1.5 min" is fine, "1.51 min" isn't.
    private static func wholeSeconds(_ seconds: Double) -> SegmentGoal? {
        guard seconds >= 1, seconds == seconds.rounded() else { return nil }
        return .time(seconds: Int(seconds))
    }
}

// MARK: - Writing

/// A plan as the dictionaries and lists `JSONSerialization` writes, in the same format reading takes.
private enum Writer {
    static func plan(_ plan: TrainingPlan) -> [String: Any] {
        var object: [String: Any] = [
            "dromo": 1,
            "title": plan.title,
            "weeks": plan.weeks.map(week),
        ]
        if let race = plan.race {
            var raceObject: [String: Any] = [
                "name": race.name,
                "date": date(race.date),
                "distance": goal(.distance(meters: race.distanceMeters)),
            ]
            if let goalTime = race.goalTimeSeconds {
                raceObject["goal"] = clock(goalTime)
            }
            object["race"] = raceObject
        }
        return object
    }

    private static func week(_ week: TrainingWeek) -> [String: Any] {
        ["title": week.title, "sessions": week.workouts.map(session)]
    }

    private static func session(_ workout: PlannedWorkout) -> [String: Any] {
        var object: [String: Any] = [
            "date": date(workout.date),
            "title": workout.title,
            "blocks": workout.blocks.map(block),
        ]
        if let start = workout.startTime {
            object["start"] = String(format: "%02d:%02d", start.hour, start.minute)
        }
        if workout.isCheckpoint {
            object["checkpoint"] = true
        }
        if let notes = workout.notes {
            object["notes"] = notes
        }
        if let warmup = workout.warmup {
            object["warmup"] = edge(warmup)
        }
        if let cooldown = workout.cooldown {
            object["cooldown"] = edge(cooldown)
        }
        return object
    }

    /// Just the length when that's all there is, as reading takes it.
    private static func edge(_ segment: WorkoutSegment) -> Any {
        if segment.pace == nil && segment.label == nil {
            return goal(segment.goal)
        }
        return step(segment)
    }

    private static func block(_ block: SegmentBlock) -> [String: Any] {
        var object: [String: Any] = ["steps": block.segments.map(step)]
        if block.repeats > 1 {
            object["repeat"] = block.repeats
        }
        return object
    }

    private static func step(_ segment: WorkoutSegment) -> [String: Any] {
        var object: [String: Any] = [segment.kind.rawValue: goal(segment.goal)]
        if let pace = segment.pace {
            object["pace"] = paceText(pace)
        }
        if let label = segment.label {
            object["label"] = label
        }
        return object
    }

    private static func paceText(_ pace: PaceRange) -> String {
        if pace.fastest == pace.slowest {
            return clock(pace.fastest)
        }
        return "\(clock(pace.fastest))–\(clock(pace.slowest))"
    }

    private static func goal(_ goal: SegmentGoal) -> String {
        switch goal {
        case .time(let seconds):
            if seconds < 60 {
                return "\(seconds) sec"
            }
            if seconds.isMultiple(of: 60) {
                return "\(seconds / 60) min"
            }
            return clock(seconds)
        case .distance(let meters):
            if meters.isMultiple(of: 1000) {
                return "\(meters / 1000) km"
            }
            if meters > 1000 && meters.isMultiple(of: 100) {
                return String(format: "%.1f km", Double(meters) / 1000)
            }
            return "\(meters) m"
        case .open:
            return "open"
        }
    }

    /// 299 → "4:59", 6300 → "1:45:00".
    private static func clock(_ seconds: Int) -> String {
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private static func date(_ date: PlanDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}
