#import "lib.typ": demo, TODAY
#import "@rheo/rookery:0.5.0": idea
#import "@rheo/rookery-todos:0.5.0": (
  epic, todo, todo-graph-view, todos-blocked, todos-list, todos-ready,
  todos-search, todos-stale, todos-stats, todos-validate,
)
#import "@rheo/rookery-dates:0.5.0": dates

#show: demo

= `@rheo/rookery-todos`

Every todo below is an ordinary `@rheo/rookery` note. Nothing is stored
anywhere else — the registry rookery already keeps IS the todo database, and
every view on this page is derived from it at build time.

== The todos

A closed todo, carrying the date it closed. Its presence in the tag dictionary
is what marks it closed; the value says when.

#todo(
  "fetch",
  title: [Fetch the source],
  priority: 0,
  type: "task",
  closed: datetime(year: 2026, month: 8, day: 1),
)[Pull the upstream tarball and verify its checksum.]

A todo with every attribute this package maps, including a metadata bag for
the things that need no filtering surface of their own.

#todo(
  "parse",
  title: [Parse the manifest],
  priority: 1,
  type: "bug",
  deps: ("fetch",),
  metadata: (estimate: 45, assignee: "lox", external-ref: "GH-412"),
  tags: ("phd",),
)[
  The manifest parser drops a trailing comma. Depends on #raw("fetch"), which is
  closed, so this one is ready.
]

Two todos that both depend on #raw("parse") — the branch in the graph below.

#todo("render", title: [Render output], deps: ("parse",))[Blocked until the parser lands.]
#todo("style", title: [Style output], deps: ("parse",), type: "chore")[Also blocked.]

A todo depending on both branches, and one depending on that in turn: three
levels deep.

#todo("ship", title: [Ship it], priority: 1, deps: ("render", "style"))[The release itself.]
#todo("docs", title: [Write the docs], type: "docs", deps: ("ship",))[Follows the release.]

A DEFERRED todo. Its `scheduled` date comes from `@rheo/rookery-dates`, merged
through `tags:` — this package takes no date parameters of its own, because
dates are one concept owned by one package.

#todo(
  "retro",
  title: [Run the retro],
  priority: 2,
  tags: dates(scheduled: datetime(year: 2026, month: 12, day: 1)),
)[Not ready until December, even though nothing blocks it.]

A todo with a DEADLINE, from the same package.

#todo(
  "audit",
  title: [Security audit],
  priority: 0,
  tags: dates(deadline: datetime(year: 2026, month: 9, day: 15)),
)[Ready now, and due next month.]

A STALE todo: open, and untouched since January.

#todo(
  "cleanup",
  title: [Clean up the fixtures],
  type: "chore",
  updated: datetime(year: 2026, month: 1, day: 1),
)[Nobody has looked at this in months.]

A todo whose dependency does not exist. A dangling dep is deliberately NOT an
error — it is reported by `#todos-validate()` and drawn dashed in the graph.

#todo("blog", title: [Write the blog post], deps: ("nope",))[Depends on a note that isn't here.]

== An epic

`#epic(name)` returns a `#todo` variant with a shared tag bound. Membership is
one more tag and nothing else: an epic creates no parent/child edge and implies
no dependency, so these two are unrelated until one names the other.

#let launch = epic("launch")
#launch("launch-plan", title: [Draft the launch plan], priority: 1)[Kick-off.]
#launch("launch-post", title: [Announce the launch], deps: ("launch-plan",))[Follows the plan.]

== Ready — `br ready`

Open, unblocked, and not deferred past today. The deferral clause is what makes
this `br`'s ready and not merely "not blocked".

#todos-ready(today: TODAY)

The same rows again with `windows: true`, each an unfoldable transclusion of
the todo's own body rather than a link to its minted page. Paged and EPUB
targets fall back to the link list above, since there is no fold to click.

#todos-ready(today: TODAY, windows: true)

== Blocked — `br blocked`

Each row names what blocks it. A list of blocked things without their blockers
tells you nothing you could act on.

#todos-blocked()

== Stale — `br stale`

Open and untouched for over 30 days. `updated` is rookery core's own field, not
a tag of ours.

#todos-stale(today: TODAY, older-than: 30)

== Stats — `br stats`

#todos-stats(today: TODAY)

== Everything open — `br list`

#todos-list(closed: false)

== Filter them

Type to narrow the list; the pills refine it further. `ready` and `blocked` are
derived from the graph and stamped in at build time, which is why no tag query
could offer them. With JavaScript off the input and pills are hidden and this is
simply a list.

#todos-search(today: TODAY)

== The dependency graph

Rendered client-side from a JSON payload. With JavaScript off it degrades to
the linked list the payload sits beside, so the dependencies stay readable.

#todo-graph-view(today: TODAY)

The same graph with `closed: false` — the open todos only, and no edge pointing
at a box that is no longer drawn. Status is still computed against the WHOLE
graph, so `parse` still reads as ready: its one dependency is the closed
`fetch`, which is done rather than merely hidden.

#todo-graph-view(today: TODAY, closed: false)

#todos-validate()
