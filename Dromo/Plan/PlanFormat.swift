import Foundation

/// What a chat assistant needs to write a plan Dromo can import: the format, by example, and the rules
/// that make it run well on the Watch. Shared from the plan screen; the tests read `example` with `PlanFile`
/// so the two can't drift apart.
enum PlanFormat {
    static func prompt(today: PlanDate) -> String {
        """
        I use Dromo, an iPhone app that puts my running sessions on my Apple Watch. Write my training plan in Dromo's plan format.

        Before writing it, ask me whatever you need: my goal or race, its date and my target time, how many days a week I can run, and my current easy pace and recent race times.

        Today is \(isoText(today)), a \(weekdayName(today)).

        Reply with the plan as JSON in a single code block, in exactly this format:

        ```json
        \(example)
        ```

        Rules:
        - "dromo" is always 1. "race" is optional: leave it out for a plan with no race. Its "goal" (a finish time) is optional too.
        - Dates are YYYY-MM-DD, no earlier than today. Group sessions into weeks, each with a title such as "Week 1".
        - Every session has a date, a title and at least one block. "notes", "warmup", "cooldown", "checkpoint" and "start" (a time like 09:30, for race day) are optional.
        - A block runs its steps in order, "repeat" times (once if left out). Each step is one of easy, work, stride, recovery or race, with its length as the value.
        - Lengths are a time ("20 sec", "1:30", "10 min"), a distance ("400 m", "1 km") or "open" to end when I choose. "warmup" and "cooldown" are just a length.
        - Paces are minutes and seconds per kilometre: "5:10–5:20" (fastest first) or "5:00".
        - Only work steps are held to a pace: their pace becomes an Apple Watch alert, so every work step needs one, about 10 seconds wide. A pace on an easy step is a rough guide shown in the app; leave paces off strides and recoveries.
        - Race steps are the race itself, run by feel: their paces are target splits shown on the Watch, never alerts. Make the last one "open" so the workout doesn't end before the finish line.
        - Set "checkpoint": true on fitness tests whose result should shape later targets, and say in the notes what success looks like.
        - Keep notes short, practical and addressed to me as "you". Metric units only. Use only the keys shown above.

        If I later send you a Dromo plan file, change only what I ask and send back the whole plan in the same format.
        """
    }

    /// One of everything the format has, small enough to read at a glance.
    static let example = """
        {
          "dromo": 1,
          "title": "10K Sub-50",
          "race": { "name": "Riverside 10K", "date": "2027-03-14", "distance": "10 km", "goal": "49:59" },
          "weeks": [
            {
              "title": "Week 1",
              "sessions": [
                {
                  "date": "2027-01-18",
                  "title": "Easy + strides",
                  "notes": "Conversational effort. Strides are relaxed and fast, never sprints.",
                  "blocks": [
                    { "steps": [{ "easy": "35 min", "pace": "5:50–6:20" }] },
                    { "repeat": 4, "steps": [{ "stride": "20 sec" }, { "recovery": "75 sec" }] }
                  ]
                },
                {
                  "date": "2027-01-21",
                  "title": "5 × 1 km",
                  "checkpoint": true,
                  "notes": "Fitness check: five even reps, the last still controlled.",
                  "warmup": "15 min",
                  "blocks": [
                    { "repeat": 5, "steps": [{ "work": "1 km", "pace": "4:55–5:05" }, { "recovery": "2 min" }] }
                  ],
                  "cooldown": "10 min"
                },
                {
                  "date": "2027-01-23",
                  "title": "Tempo 20 min",
                  "warmup": "2 km",
                  "blocks": [{ "steps": [{ "work": "20 min", "pace": "5:05–5:15", "label": "Tempo" }] }],
                  "cooldown": "1 km"
                }
              ]
            },
            {
              "title": "Race Week",
              "sessions": [
                {
                  "date": "2027-03-14",
                  "title": "Riverside 10K",
                  "start": "09:30",
                  "notes": "Start the workout on the gun. Even pace, then push the last 2 km.",
                  "blocks": [{ "steps": [
                    { "race": "5 km", "pace": "5:00", "label": "First half" },
                    { "race": "open", "pace": "4:58", "label": "Second half → finish" }
                  ] }]
                }
              ]
            }
          ]
        }
        """

    private static func isoText(_ date: PlanDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }

    /// In English whatever the phone's language, like the rest of the prompt.
    private static func weekdayName(_ date: PlanDate) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[Calendar.plan.component(.weekday, from: date.startOfDay) - 1]
    }
}
