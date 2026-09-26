import Foundation

/// The built-in six-week plan. Used until the first edit, after which PlanStore keeps its own copy on disk.
enum DefaultPlan {
    static let plan = TrainingPlan(
        title: "5K Sub-25",
        raceName: "Athens",
        raceDate: PlanDate(2026, 11, 7),
        raceDistanceMeters: 5000,
        goalTimeSeconds: 24 * 60 + 59,
        weeks: [
            TrainingWeek(id: weekID(1), title: "Week 1", workouts: [
                easyWithStrides(PlanDate(2026, 9, 28), minutes: 30, guide: PaceRange(6, 20, to: 6, 50),
                                strides: 4, strideSeconds: 15),
                session(PlanDate(2026, 10, 1), "6 × 90 sec",
                        warmup: .warmup(.minutes(10)),
                        blocks: [
                            SegmentBlock(repeats: 6, segments: [
                                .work(.seconds(90), pace: PaceRange(5, 10, to: 5, 20)),
                                .recovery(.minutes(2)),
                            ]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
                easy(PlanDate(2026, 10, 3), minutes: 40, guide: PaceRange(6, 15, to: 6, 45)),
            ]),

            TrainingWeek(id: weekID(2), title: "Week 2", workouts: [
                easyWithStrides(PlanDate(2026, 10, 5), minutes: 35, strides: 5, strideSeconds: 20),
                session(PlanDate(2026, 10, 8), "5 × 600 m",
                        warmup: .warmup(.minutes(10)),
                        blocks: [
                            SegmentBlock(repeats: 5, segments: [
                                .work(.meters(600), pace: PaceRange(5, 0, to: 5, 5)),
                                .recovery(.minutes(2)),
                            ]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
                session(PlanDate(2026, 10, 10), "Progression 45 min",
                        notes: "Controlled progression, not a hard tempo.",
                        blocks: [
                            SegmentBlock(segments: [.easy(.minutes(35))]),
                            SegmentBlock(segments: [.work(.minutes(10), pace: PaceRange(5, 45, to: 6, 0), label: "Steady")]),
                        ]),
            ]),

            TrainingWeek(id: weekID(3), title: "Week 3", workouts: [
                easyWithStrides(PlanDate(2026, 10, 12), minutes: 35, strides: 6, strideSeconds: 20),
                session(PlanDate(2026, 10, 15), "4 × 1 km",
                        notes: "Fitness checkpoint #1. Success means all four reps at a reasonably consistent pace, with the last one still controlled rather than all-out. Adjust later targets from here if needed.",
                        checkpoint: true,
                        warmup: .warmup(.minutes(10)),
                        blocks: [
                            SegmentBlock(repeats: 4, segments: [
                                .work(.kilometers(1), pace: PaceRange(5, 0, to: 5, 5)),
                                .recovery(.seconds(150)),
                            ]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
                easy(PlanDate(2026, 10, 17), minutes: 50, guide: PaceRange(6, 5, to: 6, 35)),
            ]),

            TrainingWeek(id: weekID(4), title: "Week 4", workouts: [
                easyWithStrides(PlanDate(2026, 10, 19), minutes: 35, strides: 5, strideSeconds: 20),
                session(PlanDate(2026, 10, 22), "6 × 400 m",
                        notes: "About 1:54–1:56 per 400 m. Fast but controlled — not maximal.",
                        warmup: .warmup(.minutes(10)),
                        blocks: [
                            SegmentBlock(repeats: 6, segments: [
                                .work(.meters(400), pace: PaceRange(4, 45, to: 4, 50)),
                                .recovery(.seconds(90)),
                            ]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
                session(PlanDate(2026, 10, 24), "Tempo 20 min",
                        warmup: .warmup(.minutes(15)),
                        blocks: [
                            SegmentBlock(segments: [.work(.minutes(20), pace: PaceRange(5, 15, to: 5, 25), label: "Tempo")]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
            ]),

            TrainingWeek(id: weekID(5), title: "Week 5", workouts: [
                easyWithStrides(PlanDate(2026, 10, 26), minutes: 35, strides: 5, strideSeconds: 20),
                session(PlanDate(2026, 10, 29), "3 × 1 km",
                        notes: "Fitness checkpoint #2. Consistent, controlled reps here are good evidence that sub-25 is realistic. If not, edit the race targets.",
                        checkpoint: true,
                        warmup: .warmup(.minutes(12)),
                        blocks: [
                            SegmentBlock(repeats: 3, segments: [
                                .work(.kilometers(1), pace: PaceRange(4, 50, to: 4, 55)),
                                .recovery(.seconds(150)),
                            ]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
                session(PlanDate(2026, 10, 31), "3 km at race pace",
                        notes: "Race-pace rehearsal. Should feel controlled — not a 5K time trial.",
                        warmup: .warmup(.kilometers(2)),
                        blocks: [
                            SegmentBlock(segments: [.work(.kilometers(3), pace: PaceRange(4, 55, to: 5, 5), label: "Race pace")]),
                        ],
                        cooldown: .cooldown(.kilometers(1))),
            ]),

            TrainingWeek(id: weekID(6), title: "Race Week", workouts: [
                easyWithStrides(PlanDate(2026, 11, 2), minutes: 25, strides: 4, strideSeconds: 20,
                                notes: "Should leave you feeling fresh. " + strideNotes),
                session(PlanDate(2026, 11, 5), "3 × 400 m",
                        notes: "Race sharpening: keeps you familiar with faster running while creating minimal fatigue.",
                        warmup: .warmup(.minutes(10)),
                        blocks: [
                            SegmentBlock(repeats: 3, segments: [
                                .work(.meters(400), pace: PaceRange(4, 45, to: 4, 50)),
                                .recovery(.minutes(2)),
                            ]),
                        ],
                        cooldown: .cooldown(.minutes(10))),
                session(PlanDate(2026, 11, 7), "Athens 5K",
                        startTime: PlanTime(hour: 17, minute: 0),
                        notes: "Athens Authentic Marathon COSMOTE 5K. Before the start: 12–15 min easy, 4 short relaxed strides, then easy recovery. Start this workout on the gun. Goal under 25:00 (4:59/km) — don't go out too fast: 5:04 · 5:00 · 4:59 · 4:57 · 4:53 = 24:53.",
                        blocks: [
                            // Target splits are shown on the Watch but never enforced: the race is run by feel.
                            SegmentBlock(segments: [
                                .race(.kilometers(1), split: PaceRange(5, 3, to: 5, 5), label: "KM 1"),
                                .race(.kilometers(1), split: PaceRange(5, 0, to: 5, 0), label: "KM 2"),
                                .race(.kilometers(1), split: PaceRange(4, 58, to: 5, 0), label: "KM 3"),
                                .race(.kilometers(1), split: PaceRange(4, 55, to: 4, 58), label: "KM 4"),
                                // Open-ended so the workout doesn't finish before the actual finish line.
                                .race(.open, split: PaceRange(4, 53, to: 4, 53), label: "KM 5 → finish"),
                            ]),
                        ]),
            ]),
        ]
    )

    static func workout(id: PlannedWorkout.ID) -> PlannedWorkout? {
        plan.workouts.first { $0.id == id }
    }

    // MARK: - Session templates

    /// Generous easy recovery between strides.
    private static let strideRecovery: SegmentGoal = .seconds(75)

    private static let strideNotes = "Strides are short, relaxed, smooth accelerations — fast but controlled, never sprints. Recover fully between them."

    private static func easy(_ date: PlanDate, minutes: Int, guide: PaceRange) -> PlannedWorkout {
        session(date, "Easy \(minutes) min",
                notes: "Conversational effort. The pace is a rough guide only — slow down freely for heat, hills or fatigue.",
                blocks: [SegmentBlock(segments: [.easy(.minutes(minutes), guide: guide)])])
    }

    private static func easyWithStrides(
        _ date: PlanDate,
        minutes: Int,
        guide: PaceRange? = nil,
        strides: Int,
        strideSeconds: Int,
        notes: String = "Easy, conversational effort. " + strideNotes
    ) -> PlannedWorkout {
        session(date, "Easy + strides",
                notes: notes,
                blocks: [
                    SegmentBlock(segments: [.easy(.minutes(minutes), guide: guide)]),
                    SegmentBlock(repeats: strides, segments: [.stride(.seconds(strideSeconds)), .recovery(strideRecovery)]),
                ])
    }

    private static func session(
        _ date: PlanDate,
        _ title: String,
        startTime: PlanTime? = nil,
        notes: String? = nil,
        checkpoint: Bool = false,
        warmup: WorkoutSegment? = nil,
        blocks: [SegmentBlock],
        cooldown: WorkoutSegment? = nil
    ) -> PlannedWorkout {
        PlannedWorkout(
            id: workoutID(date),
            date: date,
            startTime: startTime,
            title: title,
            notes: notes,
            isCheckpoint: checkpoint,
            warmup: warmup,
            blocks: blocks,
            cooldown: cooldown
        )
    }

    // Stable IDs so the built-in plan matches up with already-scheduled workouts across launches.
    private static func workoutID(_ date: PlanDate) -> UUID {
        UUID(uuidString: String(format: "5B250000-0000-0000-0000-%04d%02d%02d0000", date.year, date.month, date.day))!
    }

    private static func weekID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "5B250000-0000-0000-0001-%012d", number))!
    }
}

// Shorthand for writing plans.
extension WorkoutSegment {
    static func warmup(_ goal: SegmentGoal) -> WorkoutSegment { WorkoutSegment(kind: .warmup, goal: goal) }
    static func cooldown(_ goal: SegmentGoal) -> WorkoutSegment { WorkoutSegment(kind: .cooldown, goal: goal) }
    static func recovery(_ goal: SegmentGoal) -> WorkoutSegment { WorkoutSegment(kind: .recovery, goal: goal) }
    static func stride(_ goal: SegmentGoal) -> WorkoutSegment { WorkoutSegment(kind: .stride, goal: goal) }

    /// `guide` is shown in the app only; easy running never gets a Watch pace alert.
    static func easy(_ goal: SegmentGoal, guide: PaceRange? = nil) -> WorkoutSegment {
        WorkoutSegment(kind: .easy, goal: goal, pace: guide)
    }

    static func work(_ goal: SegmentGoal, pace: PaceRange, label: String? = nil) -> WorkoutSegment {
        WorkoutSegment(kind: .work, goal: goal, pace: pace, label: label)
    }

    static func race(_ goal: SegmentGoal, split: PaceRange, label: String) -> WorkoutSegment {
        WorkoutSegment(kind: .race, goal: goal, pace: split, label: label)
    }
}
