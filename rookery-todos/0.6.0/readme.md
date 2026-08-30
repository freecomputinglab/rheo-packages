# @rheo/rookery-todos

Todos, epics and a dependency DAG over [`@rheo/rookery`](../../rookery) notes.

```typst
#import "@rheo/rookery:0.6.0": rookery
#import "@rheo/rookery-todos:0.6.0": todo, todos-ready, todo-graph-view
#show: rookery

#let TODAY = datetime(year: 2026, month: 8, day: 25)

#todo("fetch", title: [Fetch the source], priority: 0, done: datetime(year: 2026, month: 8, day: 1))[...]
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
| `br search` | `#todos-search(..)` | ✅ in-page filter |
| `br ready` | `#todos-ready(today: ..)` | ✅ |
| `br blocked` | `#todos-blocked()` | ✅ |
| `br stale` | `#todos-stale(today: .., older-than: ..)` | ✅ |
| `br stats` / `count` | `#todos-stats(today: ..)` | ✅ |
| `br graph` | `#todo-graph-view(today: .., closed: ..)` | ✅ |
| `br epic` | `#epic(name)` | ✅ as a tag, not a tree |
| `br create` | `#todo(..)` | ✅ |
| `br update` / `close` / `dep add` | — | edit the `.typ` |
| `br comments` | — | the note's body |
| `br dep --type parent-child` | — | see "No parent edges" |
| `pinned`, `ephemeral`, `compaction_*`, `source_*`, `agent_context` | — | beads infrastructure |

## Closing a todo

Three spellings, one log entry — the third and the second fold into the first
before anything reads them, so they cannot disagree:

```typst
#todo("fetch", timeline: (closed: d))[...]   // the store, written directly
#todo("fetch", done: d)[...]                 // the shorthand
#let shipped = done(d)                       // the factory, for a shared date
#shipped("fetch", priority: 0)[...]
```

- **A close is a DATE.** `done: true` is refused with a message: a log entry
  needs a date, and nothing here auto-stamps one because there is no clock to
  stamp from — `datetime.today()` returns 1980-01-01 under a reproducible-build
  `SOURCE_DATE_EPOCH` and fails silently while doing it.
- **`done:` takes whatever a log entry takes**, so a close can carry its own
  prose: `done: (timestamp: d, note: [Landed as ..])`.
- **`#done(date)` is a factory**, the same shape as `#epic(name)`: it returns a
  `#todo` variant with `done:` bound and keeps the entire call surface —
  content bodies, all three id forms, `priority`, `deps`, `tags`, a further
  `timeline:` of other stages. It curries rather than taking the date as a
  leading positional argument because `#todo`'s first positional is the note's
  ID, and a date there would take that slot.
- **Closing twice is refused** — `done:` together with `timeline: (closed: ..)`
  leaves the date the todo closed on unknowable, so write one of them.

## 0.6.0 — a todo's dates are one log

**Breaking.** A close requires a `datetime`; `closed: true` is refused.

A todo already had a lifecycle — filed, scheduled, activated, closed — and it was
spread across three owners: rookery core's `minted`/`updated`,
`@rheo/rookery-timeline`' two date keys, and this package's own valued `todo-closed`.
That last one was a dated event wearing a tag's clothes. As of 0.6.0 every date a
todo carries lives in one timeline:

```typst
#todo("ship", deadline: d, timeline: (activated: d2, closed: d3))[...]
```

- **`#todo` takes `scheduled:`, `deadline:` and `timeline:` as named arguments**, being
  built on rookery-timeline's `dated(..)` decorator. The old `tags: entries(deadline: d)`
  form still works and is still supported.
- **The `closed:` ARGUMENT is gone**, and a close is a log entry: write it as
  `timeline: (closed: d)` or as the `done: d` shorthand above. `closed: true`
  used to mean "closed, when unknown"; an entry needs a date, and this package
  has no clock to stamp one from, so an undated close is simply a caller who did
  not say when. The message says so.
- **`todo-closed` survives as a FLAT marker** carrying no date. See surface 2
  below for why that is not a second copy.
- **`activated` joins the vocabulary** — the moment a todo went from ready to
  being worked on. rookery-timeline reserves `scheduled`/`deadline`/`closed` and
  leaves the rest to its consumers; a status transition is this package's to name.
- **`#todos-stale` now measures activity rather than document age.** It read
  core's `updated`, which fell back to the DOCUMENT's date — so on any project
  that did not hand-write an `updated:` per todo, "stale" reported how old the
  document was. It reads the log's last entry now.
- **`updated:` is gone from `#idea`**, so passing it to `#todo` does nothing.
  Rookery 0.6.0 removed the field.

Migrating: change every `closed: true` to `done: <the date it closed>`, and every
`closed: <datetime>` to `done: <datetime>`. If you read `closed-on`, it now comes
from the log; if you filtered on `tags:todo-closed`, that still works.

## A skin over rookery

Same pattern as `@rheo/rookery-timeline`, one layer further out: import `idea`,
`window` and the rest **from here** and get versions that know about todos.

```typst
#import "@rheo/rookery-todos:0.6.0": idea, rookery, todo, window
```

It imports the **timeline skin**, not rookery directly, so the decoration composes:
`idea` arriving here is already `dated(rookery.idea)`, and a note written through
this package takes the log arguments as well as the todo ones.

**`window` is the one name this layer overrides.** A closed todo is not transcluded:

```typst
#window("some-todo")                // renders nothing if that todo is closed
#window("some-todo", closed: true)  // opts it back in
```

A closed todo windowed into a page is noise — the thing is done, and the reason to
window a todo at all is to have it in front of you.

**Only the NAMED case is filtered**, and that is a limitation rather than an
oversight. `#window` takes either a name or a `tags:`/`match:` selection. Given a
name, this wrapper reads that note's tags and decides. Given a selection, rookery
does the selecting internally and `tags:`/`match:` are any/all over a list with **no
negation** — so a wrapper cannot express "todo and not closed", and a tag-selected
window still shows closed todos. Fixing that needs a negation or a predicate hook in
rookery's own tag predicate, not a workaround here.

**A closed todo is also greyed where it is hatched**, not only in a list view. It
needs nothing new from rookery: `.idea-box` and a note's heading already carry
`idea-tag-<key>` for every tag key, so the closed marker is on the card as a class.
The card recedes as a whole via `opacity` — one property rather than a rule per part
— and hovering restores it, since a closed todo is receded and not hidden. Override
`--todo-closed-opacity` to taste.

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
| `todo-deps` | array of note names |
| `todo-metadata` | dictionary — estimate, assignee, close-reason, external-ref, … |

**`todo-closed` moved to surface 1 in 0.6.0**, and it is worth saying why it did
not simply disappear. The DATE a todo closed lives in the log, with every other
dated event in its life — that is the whole point of 0.6.0. But rookery's tag
predicate and rookery-search's `tags:` query both test KEYS, so a fact living only
inside a tag's VALUE is invisible to them, and `tags:todo&!todo-closed` — the
payoff named at the top of surface 1 — would have been lost to buy tidiness.

So `todo-closed` is now a FLAT presence marker valued `none`, carrying no date and
duplicating nothing. `is-closed` reads either it or a `closed` entry in the log, so
a note written straight through `entries(timeline: (closed: d))` without `#todo` still
reads as closed; `closed-on` reads only the log, the one place the date is stored.
`closed: false` still emits no key at all.

**3. Not tags of ours at all.**

- **Labels are plain, unnamespaced rookery tags.** `#todo("x", tags: ("phd",))`.
  A todo's labels *are* rookery tags, and namespacing them would break exactly
  the filtering and theming that is the point.
- **Dates come from [`@rheo/rookery-timeline`](../../rookery-timeline)** —
  `#todo("x", deadline: d, timeline: (activated: d2))`, or the older
  `#todo("x", tags: entries(deadline: d))`. One concept, one package, and as of
  0.6.0 one log.
- **`created` is rookery core's own**, forwarded straight through `#todo`. There
  is no `updated` beside it any more; `updated-of(row, tags)` in rookery-timeline
  derives last-touched from the log instead.

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

### Backlinks

A `windows: true` view gives every todo it lists a backlink from the page
holding the view — the note's own page lists that page under "Context", exactly
as it would for a `#window` you wrote by hand.

That is worth knowing before putting one on a busy index: a page listing twenty
ready todos becomes a backlink on all twenty. It is not suppressible, and should
not be — the view really does reference those notes, and hiding that from the
backlink walk would make the walk lie.

This needed a fix in `@rheo/rookery` 0.5.0 to work at all. The backlink walk
reads a page's content at template time, which cannot enter a `context` block,
and these views must run inside one; a window emitted from there used to
announce itself to nobody. rookery now labels `#window`'s announce marker and
collects those by `query()` instead, which sees them wherever they were
written.

A TAG-SELECTED window is still the exception: `#window(tags: ..)` produces no
backlink for the notes its tag matched, only for ones named outright. That
asymmetry is rookery's and is documented there.

## Filtering todos in the page: `#todos-search`

```typst
#todos-search(today: TODAY)
```

A text input that fuzzy-filters the todos as you type, with the matches listed
below it as **links to each todo's minted page**, and a row of toggleable pills
that refine the set further.

```typst
#todos-search(
  title: none,
  placeholder: "Filter todos",
  today: none,
  closed: false,
)
```

`closed: false` is the default here, unlike `#todos-list` where it is `true`: a
filter box is for finding live work.

**The pills** are `ready`, `blocked`, and one per todo *type* any listed todo
actually has — no pill is emitted for a type nothing carries, since that filter
could only ever return nothing. Within a facet the values **OR** (two status
pills mean either); across facets they **AND** (`blocked` + `docs` leaves todos
that are both).

`ready` and `blocked` are stamped into each row at build time, computed against
the whole dependency graph. That is also why this widget is here rather than in
`@rheo/rookery-search`: both are derived from the graph and the calendar and
deliberately never stored as tags, so no tag query can select them.

**Searching covers the body, not just the title** — the haystack is the title,
the name and the body, so typing a phrase from inside a todo finds it.

### Without JavaScript

The input and the pills are hidden and every todo is listed as an ordinary
link. Nothing is fetched or built in the browser: Typst emits every row up
front and the script only shows, hides and reorders them. A paged or EPUB
target gets the plain list too.

### When you want the whole rookery instead

Use [`@rheo/rookery-search`](../../rookery-search). This filters *the todos on
this page*; that searches every note in the rookery, with a proper ranking and
a modal. The two are independent — this package does not depend on it, and a
project may install either alone.

## Derived, never stored

`blocked`, `ready` and `stale` are questions about the graph and the calendar as
they stand right now, not facts about a note. Tagging them would let them drift
out of step with the deps and dates that define them, and nothing would report
the drift.

`is-ready` is open **and** unblocked **and** not deferred past the reference
date. The deferral clause is what makes it br's `ready` rather than merely "not
blocked" — a todo scheduled for next week is not work you can pick up now.

`stale` changed meaning in 0.6.0 and is now worth the name. It used to read
rookery core's `updated`, which resolved from the DOCUMENT's date when a todo did
not carry one of its own — so on most projects it measured how old the document
was rather than whether anything had happened. It reads the todo's own log now:
touching a todo puts an entry in it, and that is what "untouched" is measured
against.

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
`@rheo/rookery-timeline`' readme carries the full evidence.

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

### The heat ramp: how close, and how urgent

`#filter-panel` **bands the date cell itself** on every row whose date falls within a
fortnight, in the three bands `@rheo/rookery-timeline` defines (`countdown`,
`when.typ`): urgent is today, tomorrow and anything overdue; soon is two to seven
days; later is eight to fourteen. The colour is the reading at a glance; the words —
`today`, `tomorrow`, `in 5 days`, `9 days ago` — ride as a tooltip drawn above the
cell on hover and on focus, and as its `aria-label` for a reader who cannot see a
colour. The badge strip stays about facets.

It is **on by default** here, where `#upcoming`'s own `countdown:` is off, because a
panel of outstanding work is read for what is due next. Pass `countdown: false` to
drop it, and note that it needs a `today:` — with none passed no row can be measured
and no countdown band is drawn. (`#upcoming` is untouched: that view keeps its chips.)

**Priority is the fallback, and only where the countdown is silent.** A todo three
weeks out earns no countdown band, so a `p0` sitting far out would otherwise read
exactly like the `p4` beside it; where both could apply the countdown wins, because a
deadline actually due soon is the more pressing read regardless of how it was
prioritised. `p0` takes the urgent hue, `p1` soon, `p2` later, each a touch lighter
than the countdown band of the same colour. `p3` and `p4` are left plain — a ramp of
three has three steps, and a backlog item colouring itself is the noise the ramp
exists to cut through. A row with no date is never banded: a wash behind an em dash
says nothing.

| | |
|---|---|
| `--rookery-heat-urgent` | the whole family's first step (defaults to `#b3261e`) |
| `--rookery-heat-soon` | its second (defaults to `#b3611e`) |
| `--rookery-heat-later` | its third (defaults to `#b38f1e`) |
| `--todo-band-urgent` / `--todo-band-soon` / `--todo-band-later` | the countdown wash on the date cell, overriding the mix of the ramp |
| `--todo-band-p0` / `--todo-band-p1` / `--todo-band-p2` | the priority wash, same |
| `--todo-band-fg` | the ink on a banded `soft` date, which is no longer greyed |
| `--todo-tooltip-bg` / `--todo-tooltip-fg` / `--todo-tooltip-border` / `--todo-tooltip-outline` | the drawn tooltip, falling back to rookery's own `--idea-*` |

**One ramp, two readings, and by default they are the same palette.** A site sets the
three `--rookery-heat-*` properties once on `:root` and every heat surface in the
family follows — this package's six date bands, and `#upcoming`'s countdown chips over
in `@rheo/rookery-timeline`. The `--todo-band-*` properties exist for the site that
wants urgency-in-time and urgency-in-priority to read differently, and each replaces
its band's colour whole rather than feeding a mix:

```css
:root {
  --rookery-heat-urgent: #9c3324;
  --rookery-heat-soon: #b05c12;
  --rookery-heat-later: #b08a10;
  /* ...and, only if the two should come apart: */
  --todo-band-p0: color-mix(in oklab, #6a3ab2 34%, transparent);
}
```

## The graph view degrades

**`closed: false` draws the open todos only.** An index page asking "what is
left" wants exactly that; the finished half of a release otherwise fills the
graph and the remaining work is hard to find. The default is `true`, so an
existing call is unchanged.

Edges go with the boxes: an edge into a closed todo is a *satisfied* dependency,
and drawing it would point at a box that is not on the page. A dangling
dependency — one naming a note that does not exist — is still named in the
fallback list, because it never had a box in any slice.

**Status is still computed against the whole graph**, never the slice. A todo
whose only dependency is closed reads as `ready`, which is the truth; asking the
filtered graph would report it unblocked *because invisible* rather than
unblocked *because done* — the right answer for the wrong reason, and the wrong
answer as soon as a deferred or dangling dep is involved.

`graph-slice(graph, closed: ..)` is exported if you are building your own view
and want the same rows and edges.

**The drawing reads top-down: unblocked work on the top row, arrows running
down to what it unblocks.** So an arrow means *"unblocks"*, not *"depends on"* —
the reverse of how the `deps:` you write points. That is a drawing decision
only: `deps:` in the Typst API and `from`/`to` in the JSON payload both still
describe the dependency, unchanged.

Pair it with `closed: false` and the top row is exactly the ready work.

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

- `@rheo/rookery` 0.6.0 and `@rheo/rookery-timeline` 0.6.0. Both are hard imports.
- rheo 0.6.0 or later, inherited from rookery's own floor.
- A built package: `dist/` must exist before a project sees an edit.

## Development

```sh
cd rookery-todos/0.6.0
just build      # bundles src/ into dist/
just test       # Typst unit fixture
just test-js    # graph layout tests
rheo compile demo/rheo
```

The demo exercises every surface above: twelve todos, a three-level two-branch
DAG, a closed todo, a deferred one, one with a deadline, a stale one, a dangling
dependency, an epic, and all six views.
