// Row 4: `feed(...)` with no `title` must panic the build, not fall back to
// anything (no HTML spine title, no project directory name — the retired
// Rust generator's fallback chain has no equivalent here). `../run.sh`
// asserts this compile FAILS and that the package's own message appears.
#import "@rheo/feeds:0.1.0": feed, configure

#configure(feeds: (
  feed(
    base-url: "https://example.com",
    sources: (
      cfg => (
        (
          title: "Untitled",
          url: "https://example.com/x",
          updated: datetime(year: 2026, month: 1, day: 1),
        ),
      ),
    ),
  ),
))

= No Title

This project's own `feed(...)` call omits `title:` — the build must fail
before this page is ever laid out.
