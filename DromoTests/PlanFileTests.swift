import Foundation
import Testing
@testable import Dromo

// Plans come from AI chats: they must read the way a chat writes them, fail with problems a chat can fix,
// and keep session IDs stable so the Watch and done marks survive a re-import.

struct PlanFileTests {
    @Test func bundledPlanKeepsTheIDsAlreadyOnTheWatch() throws {
        let plan = BundledPlan.plan
        #expect(plan.workouts.count == 18)
        #expect(plan.workouts.first?.id == UUID(uuidString: "5B250000-0000-0000-0000-202609280000"))
        #expect(plan.weeks.first?.id == UUID(uuidString: "5B250000-0000-0000-0001-000000000001"))
        #expect(plan.race == Race(name: "Athens", date: PlanDate(2026, 11, 7), distanceMeters: 5000, goalTimeSeconds: 24 * 60 + 59))
        #expect(plan.raceWorkout?.startTime == PlanTime(hour: 17, minute: 0))
    }

    @Test func writingAndReadingBackChangesNothing() throws {
        let text = PlanFile.write(BundledPlan.plan)
        let read = try PlanFile.read(text)
        #expect(PlanFile.write(read) == text)
        #expect(read.workouts.map(\.id) == BundledPlan.plan.workouts.map(\.id))
    }

    @Test func thePromptsExampleReads() throws {
        let plan = try PlanFile.read(PlanFormat.example)
        #expect(plan.title == "10K Sub-50")
        #expect(plan.race?.goalTimeSeconds == 49 * 60 + 59)
        #expect(plan.workouts.count == 4)
        let check = try #require(plan.workouts.first { $0.isCheckpoint })
        #expect(check.blocks[0].repeats == 5)
        #expect(check.blocks[0].segments[0].pace == PaceRange(fastest: 295, slowest: 305))
        #expect(plan.raceWorkout?.startTime == PlanTime(hour: 9, minute: 30))
        #expect(plan.raceWorkout?.blocks[0].segments.last?.goal == .open)
    }

    @Test func thePromptCarriesTodayAndTheExample() {
        let prompt = PlanFormat.prompt(today: PlanDate(2026, 9, 27))
        #expect(prompt.contains("Today is 2026-09-27, a Sunday."))
        #expect(prompt.contains(PlanFormat.example))
    }

    @Test func movingOneSessionKeepsEveryOtherID() throws {
        var plan = BundledPlan.plan
        plan.weeks[1].workouts[2].date = PlanDate(2026, 10, 11)
        let read = try PlanFile.read(PlanFile.write(plan))
        let before = BundledPlan.plan.workouts.map(\.id)
        let after = read.workouts.map(\.id)
        #expect(zip(before, after).filter { $0 != $1 }.count == 1)
    }

    @Test func twoSessionsOnOneDayGetTheirOwnIDs() throws {
        let plan = try PlanFile.read(json(sessions: [
            #"{ "date": "2026-10-08", "title": "Morning", "blocks": [{ "steps": [{ "easy": "30 min" }] }] }"#,
            #"{ "date": "2026-10-08", "title": "Evening", "blocks": [{ "steps": [{ "easy": "20 min" }] }] }"#,
        ]))
        #expect(plan.workouts.map(\.id) == [PlanFile.workoutID(PlanDate(2026, 10, 8), slot: 0), PlanFile.workoutID(PlanDate(2026, 10, 8), slot: 1)])
    }

    @Test func aPlanNeedsNoRace() throws {
        let plan = try PlanFile.read(json(sessions: [#"{ "date": "2026-10-08", "title": "Easy", "blocks": [{ "steps": [{ "easy": "30 min" }] }] }"#]))
        #expect(plan.race == nil)
        #expect(plan.raceWorkout == nil)
    }

    @Test func findsThePlanInAChatReply() throws {
        let reply = """
            Here's your plan:
            ```json
            \(PlanFormat.example)
            ```
            Good luck with the race!
            """
        #expect(try PlanFile.read(reply).title == "10K Sub-50")
        let curly = PlanFormat.example.replacingOccurrences(of: "\"title\"", with: "“title”")
        #expect(try PlanFile.read(curly).title == "10K Sub-50")
    }

    @Test func reportsEveryProblemAndWhereItIs() {
        let text = json(sessions: [
            #"{ "date": "2026-10-08", "title": "Intervals", "blocks": [{ "repeat": 6, "steps": [{ "work": "90 sec", "pase": "5:10" }, { "recovery": "2 min" }] }] }"#,
            #"{ "date": "2026-10-10", "title": "Tempo", "blocks": [{ "steps": [{ "work": "20 min", "pace": "fast" }] }] }"#,
            #"{ "date": "2026-02-30", "title": "Easy", "blocks": [{ "steps": [{ "easy": "30" }] }] }"#,
        ])
        let problems = problemsOf(text)
        let day = PlanDate(2026, 10, 8).shortText
        #expect(problems.contains { $0.hasPrefix("Week 1 · \(day): Dromo doesn't read \"pase\"") })
        #expect(problems.contains { $0.hasPrefix("Week 1 · \(day): work steps need a pace") })
        #expect(problems.contains { $0.contains("“fast” isn't a pace") })
        #expect(problems.contains { $0 == "Week 1, session 3: “2026-02-30” isn't a date. Write it like 2026-10-08." })
        #expect(problems.count == 4)
    }

    @Test func somethingThatIsntJSONGetsOneClearProblem() {
        #expect(problemsOf("Sure! What's your goal race?") == [
            "This isn't a plan Dromo can read. Copy the whole JSON reply, from the first { to the last }.",
        ])
    }

    @Test(arguments: [
        ("90 sec", SegmentGoal.time(seconds: 90)), ("90s", .time(seconds: 90)), ("1:30", .time(seconds: 90)),
        ("1:30 min", .time(seconds: 90)), ("10 min", .time(seconds: 600)), ("1 h", .time(seconds: 3600)),
        ("1:05:00", .time(seconds: 3900)), ("600 m", .distance(meters: 600)), ("0.6 km", .distance(meters: 600)),
        ("1,5 km", .distance(meters: 1500)), ("5K", .distance(meters: 5000)), ("Open", .open),
    ])
    func readsLengthsTheWayChatsWriteThem(text: String, goal: SegmentGoal) {
        #expect(Parse.goal(text) == goal)
    }

    @Test(arguments: ["10", "fast", "1:3", "0 min", "1:75", "10 laps"])
    func rejectsLengthsItCantBeSureOf(text: String) {
        #expect(Parse.goal(text) == nil)
    }

    @Test func readsPacesInEitherOrder() {
        let window = PaceRange(fastest: 310, slowest: 320)
        #expect(Parse.pace("5:10–5:20") == window)
        #expect(Parse.pace("5:10-5:20/km") == window)
        #expect(Parse.pace("5:10 to 5:20") == window)
        #expect(Parse.pace("5:20 - 5:10") == window)
        #expect(Parse.pace("5:00") == PaceRange(fastest: 300, slowest: 300))
        #expect(Parse.pace("1:00") == nil)  // Faster than anyone runs.
        #expect(Parse.pace("5.10") == nil)
    }

    @Test func oldSavedPlansStillLoad() throws {
        // Before races became optional, a saved plan kept the race in four fields of its own.
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(BundledPlan.plan)) as? [String: Any])
        object["race"] = nil
        object["raceName"] = "Athens"
        object["raceDate"] = ["year": 2026, "month": 11, "day": 7]
        object["raceDistanceMeters"] = 5000
        object["goalTimeSeconds"] = 1499
        let plan = try JSONDecoder().decode(TrainingPlan.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(plan.race == BundledPlan.plan.race)
        #expect(plan.workouts.map(\.id) == BundledPlan.plan.workouts.map(\.id))
    }

    private func json(sessions: [String]) -> String {
        #"{ "dromo": 1, "title": "Test", "weeks": [{ "title": "Week 1", "sessions": ["# + sessions.joined(separator: ", ") + "] }] }"
    }

    private func problemsOf(_ text: String) -> [String] {
        do {
            _ = try PlanFile.read(text)
            return []
        } catch {
            return error.messages
        }
    }
}

struct PaceScaleTests {
    @Test func bundledPlanScalesFromItsOwnPaces() {
        // Easy: the middle of its easy guides (6:20–6:50, 6:15–6:45, 6:05–6:35). Fastest: the 400s at 4:45.
        #expect(BundledPlan.plan.paceScale == PaceScale(easy: 390, fastest: 285))
    }

    @Test func aBeginnersIntervalsStillLookHard() throws {
        let plan = try PlanFile.read("""
            { "dromo": 1, "title": "First 5K", "weeks": [{ "title": "Week 1", "sessions": [
              { "date": "2026-10-05", "title": "Easy", "blocks": [{ "steps": [{ "easy": "30 min", "pace": "7:45–8:15" }] }] },
              { "date": "2026-10-08", "title": "Intervals", "blocks": [{ "repeat": 4, "steps": [{ "work": "2 min", "pace": "6:40–6:50" }, { "recovery": "2 min" }] }] }
            ] }] }
            """)
        let scale = plan.paceScale
        let work = try #require(plan.workouts[1].blocks[0].segments.first)
        #expect(scale == PaceScale(easy: 480, fastest: 400))
        #expect(work.intensity(on: scale) > 0.95)
        // On the old fixed scale (6:30–4:40/km) the same intervals barely registered.
        #expect(work.intensity(on: PaceScale(easy: 390, fastest: 280)) == 0.6)
    }

    @Test func aPlanWithoutPacesUsesTheStandardScale() throws {
        let plan = try PlanFile.read("""
            { "dromo": 1, "title": "Base", "weeks": [{ "title": "Week 1", "sessions": [
              { "date": "2026-10-05", "title": "Easy", "blocks": [{ "steps": [{ "easy": "30 min" }] }] }
            ] }] }
            """)
        #expect(plan.paceScale == .standard)
    }
}
