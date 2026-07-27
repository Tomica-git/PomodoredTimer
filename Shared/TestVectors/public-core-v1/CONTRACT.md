# Public Timer Core Contract v1

This contract shares behavior, not persisted files, between macOS Swift and Windows C#.

- All elapsed-time calculations use an injected absolute timestamp. UI refresh frequency never changes the deadline.
- The red fast hand is visual only and is clamped to 0.5–5x.
- The black hand and remaining sector use real remaining time.
- A focus completion increments the completed set count. Every configured Nth focus moves to a long break; other focus completions move to a short break. Every break moves to focus.
- Paused wall-clock time is excluded from elapsed time and activity history.
- Activity history records absolute instants, displays them in the user's current time zone, and retains 90 days.
- Week views start on Monday. `weekCases` is the normative cross-platform proof for week boundaries. Day, week, and month ranges are local-calendar ranges and must handle day boundaries and DST.
- Persistence is platform-specific. Windows must not read, import, search for, or serialize the macOS UserDefaults representation.
- `timer-vectors.json` contains no user records, URLs, host paths, or personal-edition identifiers.
