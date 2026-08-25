# @rheo/rookery-todos

Todos, epics and a dependency DAG over [`@rheo/rookery`](../../rookery) notes.

```typst
#import "@rheo/rookery:0.5.0": rookery
#import "@rheo/rookery-todos:0.5.0": todo, todos-ready, todo-graph-view
#show: rookery

#let TODAY = datetime(year: 2026, month: 8, day: 25)

#todo("fetch", title: [Fetch the source], priority: 0, closed: true)[...]
#todo("parse", title: [Parse it], priority: 1, type: "bug", deps: ("fetch",))[...]

#todos-ready(today: TODAY)
#todo-graph-view(today: TODAY)
```

A todo is an ordinary rookery note carrying a `todo` tag. **Nothing is stored
anywhere else** — the registry rookery already keeps *is* the todo database, and
every view here is derived from it at build time.

## What this is, and what it is not

This simulates much of the useful surface of [`br`](https://github.com/steveyegge/beads),
the beads issue tracker. The framing that decides what made it in:

> **br is a mutable SQLite database; this is a static build.**

So this package ports br's **derived views** and not its **mutation surface**.
A status change here is an edit to a `.typ` file, which is the point rather than
a shortcoming.

| `br` | here | |
| --- | --- | --- |
| `br list` | `#todos-list(..)` | ✅ |
| `br ready` | `#todos-ready(today: ..)` | ✅ |
| `br blocked` | `#todos-blocked()` | ✅ |
| `br stale` | `#todos-stale(today: .., older-than: ..)` | ✅ |
| `br stats` / `count` | `#todos-stats(today: ..)` | ✅ |
| `br graph` | `#todo-graph-view(today: ..)` | ✅ |
| `br epic` | `#epic(name)` | ✅ as a tag, not a tree |
| `br create` | `#todo(..)` | ✅ |
| `br update` / `close` / `dep add` | — | edit the `.typ` |
| `br comments` | — | the note's body |
| `br dep --type parent-child` | — | see "No parent edges" |
| `pinned`, `ephemeral`, `compaction_*`, `source_*`, `agent_context` | — | beads infrastructure |

## The three tag surfaces

This is the whole design of the package. Read it before adding an attribute.

**1. Flat, key encodes the value.** Value `none`, so each renders as a pill,
emits a `.idea-tag-<key>` class, and is filterable by rookery's own
`#window(tags:)`/`#ideas(tags:)` *and* by `@rheo/rookery-search`'s tag query
language.

| key | from |
| --- | --- |
| `todo` | every todo |
| `todo-p0` … `todo-p4` | `priority:` (0 = critical, br's scale) |
| `todo-task`, `todo-bug`, `todo-feature`, `todo-epic`, `todo-chore`, `todo-docs`, `todo-question` | `type:` |
| `todo-in-progress`, `todo-deferred`, `todo-draft` | `status:` |
| `epic-<name>` | `#epic(name)` |

The payoff is concrete and costs this package nothing: **`tags:todo&!todo-closed`
in a search bar lists open todos**, with no rookery-todos code involved.

**2. Valued.** No pill, but the KEY is still present, so a valued tag is still
presence-filterable — `#window(tags: "todo-deps")` finds every todo with
dependencies.

| key | value |
| --- | --- |
| `todo-closed` | `datetime` or `none`. **Presence means closed**; the value says when. |
| `todo-deps` | array of note names |
| `todo-metadata` | dictionary — estimate, assignee, close-reason, external-ref, … |

`todo-closed` doing double duty is why there is no separate flat `closed`
status key: one fact, one place. `closed: false` therefore emits **no key at
all** — a key valued `false` would read as closed to everything that tests for
the key.

**3. Not tags of ours at all.**

- **Labels are plain, unnamespaced rookery tags.** `#todo("x", tags: ("phd",))`.
  A todo's labels *are* rookery tags, and namespacing them would break exactly
  the filtering and theming that is the point.
- **Dates come from [`@rheo/rookery-dates`](../../rookery-dates)** —
  `#todo("x", tags: dates(deadline: d))`. One concept, one package.
- **Created and updated are rookery core's own** `minted`/`updated`, forwarded
  straight through `#todo`.

## Rows as windows: `windows:`

`todos-list`, `todos-ready`, `todos-blocked` and `todos-stale` each take
`windows: false`. Set it and every row renders as a folded
[`#window`](../../rookery) — the todo's own body, one click away, in place —
instead of a link to its minted page.

```typst
#todos-ready(today: TODAY, windows: true)
```

**It defaults to `false`**, so nothing changes for an existing project: with the
flag unset the views emit exactly the markup they did before.

**Paged and EPUB targets fall back to the link list.** A PDF has no fold to
click, so a window row there would be a heading with a body under it and no way
to tell it from the surrounding prose. That is a deliberate branch, not a gap.

**Why the flag lives here rather than in your project:** `ready` and `blocked`
are derived from the dependency graph and the calendar, never stored as tags, so
no `#window(tags: ..)` selection can express them. Only code that has already
computed the rows can hand `#window` the names.

### Backlinks: these transclusions do not produce them

A `#window` written by hand in a vertebra announces the ids it transcludes, and
the target note's page then lists that vertebra under "Context". **A window
emitted by one of these views does not.**

MEASURED, one note and one otherwise-empty page holding only a view:

| the page holds | backlink on the note |
| --- | --- |
| `#window("solo", folded: true)`, written by hand | `board.html` appears |
| `#todos-ready(windows: true)` | nothing |

The difference is where the window is emitted from. These views run inside a
`context` block — they must, since the graph and the reference date are only
resolvable there — and rookery's backlink walk does not see a window announced
from inside one.

So a `windows: true` view is invisible to the backlink graph. Whether that is
right is arguable: the view genuinely does reference every note it unfolds, and
a reader of one of those notes is arguably owed the pointer back. It is tracked
rather than settled — see the note in `src/views.typ`. Do not rely on either
behaviour staying as it is.

## Derived, never stored

`blocked`, `ready` and `stale` are questions about the graph and the calendar as
they stand right now, not facts about a note. Tagging them would let them drift
out of step with the deps and dates that define them, and nothing would report
the drift.

`is-ready` is open **and** unblocked **and** not deferred past the reference
date. The deferral clause is what makes it br's `ready` rather than merely "not
blocked" — a todo scheduled for next week is not work you can pick up now.

## No parent edges

Todos are networked **purely** through `deps:`. There is no `todo-parent` key
and no containment tree.

An epic is therefore a tag, not a parent: `#epic("launch")` returns a `#todo`
variant with `epic-launch` bound, and two todos in one epic are unrelated until
one names the other in its `deps:`.

```typst
#let launch = epic("launch")
#launch("plan", priority: 1)[Kick-off.]
#launch("post", deps: ("plan",))[Follows the plan.]
```

The factory keeps `#todo`'s entire call surface — content bodies, all three
`#idea` id forms, every named argument.

## A cycle is a build error

...but it **cannot** be caught at the `#todo` call site, and it is worth knowing
why. `#todo("a", deps: ("b",))` is perfectly legal before `b` exists; the graph
only exists once the registry is final. There is no moment during authoring at
which a cycle is visible.

So the guarantee is assembled from two halves:

- **Every view** runs the cycle check before rendering and panics, naming the
  full path: `dependency cycle: c -> d -> c`.
- **`#todos-validate()`** does the same for a project that renders no view.
  Drop it at bundle root.

Between them a cycle cannot survive a build.

`#todos-validate()` also reports what cannot be a warning: **Typst gives package
code no `warn()`**, only `panic`. So the dangling-dependency and auto-id smells
are emitted into the compiled output (hidden by default) rather than failing a
build that has not actually broken. Pass `strict: true` to turn them into errors.

**Pin any todo something else depends on.** Rookery's unnamed notes take a
sequence number, so `#todo[..]` is `idea:1` — and that number *shifts* when a
note is inserted earlier in the spine, while a `deps` entry naming it does not
follow.

## There is no wall clock

Every view needing a "now" takes an explicit `today:`, falling back to the
document's `#set document(date:)`, and panics if neither is available.

**No function in this package calls `datetime.today()`.** It returns
1980-01-01 wherever `SOURCE_DATE_EPOCH` is set for reproducible builds
(MEASURED, typst 0.15.1) and it does not error while doing it — a stale-todo
report built on it would silently list the entire project.
`@rheo/rookery-dates`' readme carries the full evidence.

## Styling

Everything ships in `@layer rookery-todos`, and that is load-bearing. Package
stylesheet order is **not** controllable — rheo collects `css_stylesheet` assets
in package resolution order — so this package cannot rely on landing after
rookery's. A layer settles it regardless of source order, the same device
rookery uses for `@layer rookery-tags`. An unlayered project stylesheet still
beats every layer.

Colours are custom properties with fallbacks, so restyle by setting the property
rather than by out-specifying a selector: `--todo-ready-color`,
`--todo-blocked-color`, `--todo-stale-color`, `--todo-muted-color`,
`--todo-graph-line`, `--todo-graph-edge-color`.

Rows and graph nodes also wear the note's own `.idea-tag-<key>` classes, so
`.idea-tag-todo-p0` styles a critical todo on its card, in a list row, and in
the graph alike.

## The graph view degrades

`#todo-graph-view` emits an SVG drawn client-side from a JSON payload. With
JavaScript off the payload's neighbouring linked list stays in place, so the
todos and their dependencies are still readable; the script removes the
fallback only once it has drawn something.

**On a paged target that same list is the whole rendering.** Every view here
branches on the target: HTML and EPUB get `html.elem` markup, and a PDF gets
plain Typst content — a `list()` of rows for the lists, a comma-joined line for
the stats, and the graph's fallback list for the graph, since there is no
layout engine for a directed graph Typst-side. Counts are computed once and
rendered twice, so the two targets cannot disagree.

The payload is JSON-safe by construction: strings, numbers, booleans and arrays
only, never a raw tag value. A value can be a `datetime` or content, and
`json.encode` of content does **not** error — it silently emits a structural
blob and bloats the page.

## Requirements

- `@rheo/rookery` 0.5.0 and `@rheo/rookery-dates` 0.5.0. Both are hard imports.
- rheo 0.6.0 or later, inherited from rookery's own floor.
- A built package: `dist/` must exist before a project sees an edit.

## Development

```sh
cd rookery-todos/0.5.0
just build      # bundles src/ into dist/
just test       # Typst unit fixture
just test-js    # graph layout tests
rheo compile demo/rheo
```

The demo exercises every surface above: twelve todos, a three-level two-branch
DAG, a closed todo, a deferred one, one with a deadline, a stale one, a dangling
dependency, an epic, and all six views.
