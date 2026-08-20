# @rheo/feeds

Syndication feeds for Rheo projects, in pure Typst — Atom 1.0, RSS 2.0 and JSON
Feed 1.1 from one config. This package replaces the Rust feed generator retired
from rheo core, the same way `@rheo/blogfeed` and `@rheo/sidebar` moved other
project-shaped concerns out of the engine before it; that generator emitted Atom
alone, so the other two formats are new here rather than restored.

```typst
#import "@rheo/feeds:0.1.0": feed, configure, spine

#configure(feeds: (
  feed(
    title: "My Site",
    base-url: "https://example.com",
    sources: (spine(),),
  ),
))
```

Call this once, from any vertebra, and every vertebra in the spine becomes a
candidate entry in `feed.xml` — the same default the retired Rust generator
had. Everything below fills in what that example glosses over: the two ways to
register a feed, what a feed config's fields mean, how to write your own
source instead of the built-in one, and how to migrate a project off the old
`[html]` feed keys. Every piece described here — the entry model, both entry
points, the built-in sources, the beacon protocol, and the Atom serializer —
is implemented and exercised end to end by `demo/` and `verify/`, both
described near the bottom of this file.

## Two entry points: `configure(...)` and `emit(...)`

There are two independent ways to register a feed, and a project uses exactly
one of them.

**(a) `configure(...)`, called from any vertebra.** This is the path the
example above takes. `configure` appends onto a document-wide `state`; this
package's own `.marrow.typ` — spliced into rheo's bundle root automatically,
no `rheo.toml` entry needed — reads that state once, at the end of the build,
and mints every feed it finds:

```typst
#import "@rheo/feeds:0.1.0": feed, configure

#configure(feeds: (
  feed(title: "My Site", base-url: "https://example.com", sources: (...)),
))
```

**(b) `emit(...)`, called from your own project's `.marrow.typ`.** For a
project that would rather assemble its feeds itself than rely on the package's
minted one:

```typst
// content/.marrow.typ
#import "@rheo/feeds:0.1.0": feed, emit

#context {
  emit(feeds: (
    feed(title: "My Site", base-url: "https://example.com", sources: (...)),
  ))
}
```

The `#context` here is for `emit` itself, which may run sources (`spine()`,
`items()`) that query the document. `configure` needs no such wrapping at
your call site, because it only appends to a state — the context-requiring
read of that state happens once, inside this package's own `.marrow.typ`, not
wherever you call `configure`. Use (a) unless you already have a reason to
write your own bundle-root marrow; a project picks one path, not both.

## The shapes: entry, source, feed config

Three shapes make up the whole surface, and `resolve-entries` is what turns a
source's sparse output into the first of them.

### Entry

A source need not fill every field — only `title` is mandatory on the way in.
`resolve-entries` fills or defaults the rest, per this table:

| Field | Type | Required | Default |
| --- | --- | --- | --- |
| `title` | `str` or `content` | yes | — |
| `url` | `str`, absolute | one of `url`/`page` | built from `base-url` + `page` when absent |
| `page` | `str`, plugin-output-relative | one of `url`/`page` | — |
| `published` | `datetime` | one of `published`/`updated`* | — |
| `updated` | `datetime` | one of `published`/`updated`* | falls back to `published` when only that is given |
| `id` | `str`, stable and globally unique | no | falls back to `url` |
| `select` | `str`, a region selector passed to rheo | no | `none` |
| `summary` | `str` | no | `none` |
| `categories` | array of `str` | no | `()` |
| `author` | `str` | no | falls back to the feed's own `author` |

\* An entry with neither `published` nor `updated` is not an error — it is
silently dropped from the feed. See "Migrating" below for why, and for what
this replaces.

Every one of those types is checked, and the error names this package and the
field rather than surfacing from somewhere inside the XML serializer. Three are
worth calling out because the wrong value looks plausible: a `url` must be
ABSOLUTE (a page-relative path belongs in `page`, which is joined onto
`base-url` for you); `categories` must be an array even for a single tag, so
`("note",)` and never `"note"`; and a date must be a real
`datetime(year: .., month: .., day: ..)`, never a string — see
"Migrating" below, since the variable this field replaces did take one.

### Source

A source is not a shape with fields to fill in — it is a plain function of one
argument, `cfg => (entries)`, where `cfg` is the resolved feed config (the same
dict `feed(...)` returns) and the return value is an array of entries. There is
no source registry and no descriptor dict. A built-in source such as `spine`
takes its own options and *returns* the source, so it reads as an ordinary call
at the call site — `spine(select: "main")` — and a hand-written source is any
function of the same shape, with nothing package-specific about it:

```typst
#let my-source(cfg) = ((title: "Hello", url: cfg.base-url + "/hi"),)
```

`.with(...)` does **not** work here, and the mistake is an easy one: a source
takes its `cfg` positionally, while `spine` itself takes none, so
`spine.with(select: "main")` yields a function that still refuses a positional
argument and fails with `error: unexpected argument` the moment
`resolve-entries` calls it. Write `spine(select: "main")`.

A Typst `state` can hold a function and still call it after `.final()`, which
is why a `sources` array survives all the way from `configure(...)`'s call
site to `.marrow.typ`'s own read of it, functions and all — you never lose the
closure over whatever the source captured.

### Feed config

What `feed(...)` builds and validates, and what every source's `cfg` argument
is:

| Field | Type | Required | Default |
| --- | --- | --- | --- |
| `title` | `str`, non-empty | yes | — |
| `base-url` | `str`, absolute (a scheme, e.g. `https://`) | yes | — |*
| `sources` | array of functions, at least one | yes | — |
| `path` | `str` | no | `"feed.xml"` |
| `author` | `str` | no | `"Rheo"` |
| `subtitle` | `str` or `none` | no | `none` |
| `format` | `"atom"`, `"rss"`, or `"json"` | no | `"atom"` |
| `content` | `"html"`, `"xhtml"`, or `none` | no | `"html"` |
| `limit` | positive integer or `none` | no | `none` (no limit) |

\* `base-url` does double duty: besides prefixing an entry's `page` into an
absolute URL, it is emitted as the feed's own
`<link rel="alternate">` — the site a reader "visits" from a subscription,
distinct from `rel="self"`, which is the feed file itself.

`content` governs what an entry's `<content>` element resolves to: `"html"`
and `"xhtml"` both splice in the entry's own `page` via rheo's
`<rheo-content>` transclusion (`"xhtml"` wraps it in the XHTML content model
Atom's `type="xhtml"` requires); `none` skips `<content>` entirely. A
`summary`, where an entry supplies one, is always emitted — alongside
`<content>` rather than instead of it, which Atom permits and readers use for
list previews. `<rheo-content>` and rheo's
other build-time control assets are rheo's own contract, not this package's —
see [rheo.ohrg.org](https://rheo.ohrg.org) for that half.

## Three formats, and what does not transfer between them

`format` picks the serializer: `"atom"` emits Atom 1.0, `"rss"` emits RSS 2.0,
`"json"` emits JSON Feed 1.1. One project can register the same sources at
three paths and get all three, from one `configure(...)` call:

```typst
#import "@rheo/feeds:0.1.0": feed, configure, spine

#let posts = spine(filter: e => e.handle.starts-with("posts:"))

#configure(feeds: (
  feed(path: "feed.xml", title: "My Site", base-url: "https://example.com", sources: (posts,)),
  feed(path: "rss.xml", title: "My Site", base-url: "https://example.com", sources: (posts,), format: "rss"),
  feed(
    path: "feed.json",
    title: "My Site",
    base-url: "https://example.com",
    sources: (posts,),
    format: "json",
    content: none,
  ),
))
```

Every page's `<head>` then carries one autodiscovery `<link>` per feed, each
with its own type — `application/atom+xml`, `application/rss+xml`,
`application/feed+json`.

The entry model is shared, but the formats are not equivalent, and the
differences are mappings rather than omissions:

- **RSS has one date per item.** Atom's `published`/`updated` distinction has no
  RSS slot, so `pubDate` takes `published` when present and `updated`
  otherwise. The channel's `lastBuildDate` carries the newest `updated`.
- **RSS's own `<author>` element must hold an email address.** This package's
  `author` is a plain name, so it goes in `<dc:creator>` — a name in
  `<author>` produces a feed validators reject. It is emitted on every item,
  because RSS has no channel-to-item author inheritance the way Atom does.
- **`content: "xhtml"` is Atom-only**, being Atom's own `type="xhtml"` content
  model. Pairing it with another format fails the build rather than being
  quietly reinterpreted.
- **JSON Feed is summary-only for now**, and this is a rheo limitation rather
  than a package one: `<rheo-content>` transclusion has no JSON-safe encoding,
  so there is no way to put a page's compiled HTML inside a JSON string
  without either breaking the JSON or leaving the placeholder unresolved.
  `format: "json"` therefore requires `content: none`, so the constraint is
  something you acknowledge rather than something that silently drops your
  content. Tracked in the rheo repo as bead `rheo-rheo-content-json-vxv`.
- **A `guid`'s `isPermaLink` is `false` when an entry's `id` is not a URL** —
  rookery-sourced ids like `idea:beta` are the common case. This is why an `id`
  need not be a URL at all; a reader would otherwise try to follow it.

## The built-in `spine()` source

`spine(filter: none, select: none)` reproduces what the retired Rust generator
did by default: every vertebra in the spine is a candidate entry. `filter`,
when given, is a predicate over the spine entry (`handle`, `path`, `title`),
run before anything else — `demo/`'s posts feed narrows to one directory this
way, depth-independent because the check is against the handle, not the
path:

```typst
feed(
  path: "feed.xml",
  title: "Rssfeed Demo — Posts",
  base-url: "https://demo.example.org",
  sources: (spine(filter: e => e.handle.starts-with("posts:")),),
)
```

Each entry's `title` prefers the vertebra's own authored `#set
document(title: ...)` over the filename-derived fallback rheo's spine data
otherwise carries. `published` and `updated` both come from that same
vertebra's `#set document(date: ...)`, and `categories` from its `keywords`.
`select`, when given, is passed through to every entry from this source
unchanged. A vertebra with no `#set document(date: ...)` of its own, and
nothing else supplying a date, yields an entry with neither `published` nor
`updated` — dropped by the skip rule above, which is how a cover page or index
falls out of a spine-sourced feed. See "Migrating" below for what this
replaces.

## Sourcing from another package: the `ideas(tags:)` recipe

Reach for this first whenever the data you want to syndicate already has a
synchronous accessor — a function you can call, right now, that hands back an
array. `@rheo/rookery`'s `ideas(tags:)` is exactly that, and this is the
recipe `demo/content/index.typ` uses, verbatim, to build `notes.xml`:

```typst
#import "@rheo/feeds:0.1.0": feed, configure, spine
#import "@rheo/rookery:0.3.0": ideas

#let from-ideas(tags: none, match: "any") = cfg => (
  ideas(tags: tags, match: match)
    .filter(e => e.page != none and e.updated != none)
    .map(e => (
      id: e.id,
      title: e.text,
      page: e.page,
      updated: e.updated,
      published: e.minted,
      categories: e.tags,
    ))
)

#configure(feeds: (
  feed(
    path: "notes.xml",
    title: "Rssfeed Demo — Notes",
    base-url: "https://demo.example.org",
    author: "The Rookery",
    sources: (from-ideas(tags: "note"),),
  ),
))
```

Neither package imports the other, in either direction. `ideas()` is
rookery's own public API, called here by the *project*; `from-ideas` is
nothing more than a plain function shaped `cfg => (entries)`, the same shape
every source has, and `@rheo/feeds` never sees `@rheo/rookery` at all. The
parentheses wrapping the `.filter(...).map(...)` chain are load-bearing, not
decorative: written across several lines without them, the chained calls fall
outside the `#let`'s single expression and back into markup, which renders as
a literal paragraph of code rather than binding a function.

The `.filter(...)` ahead of the `.map(...)` matters too. It drops any note
with no minted page or no date before it ever becomes a candidate entry — the
same skip rule `resolve-entries` enforces on every source's output, just
applied a step earlier here, so an unminted or undated note never reaches
`@rheo/feeds`'s own validation at all.

This generalises past rookery: anything with its own array-returning
accessor — another package's registry, a hand-rolled list of dictionaries,
`query()` over your own beacons — becomes a source the same way, wrapped in a
few lines that reshape its fields into the entry table above. Reach for the
beacon protocol below only when there is no such accessor to call.

## The `<feeds:item>` beacon protocol

This is the fallback, not the first thing to reach for: use it when the data
has no `ideas()`-style accessor to call — an arbitrary hand-authored page with
no registry behind it, or a package that holds its own data but exposes no
synchronous function for `@rheo/feeds` (or anything else) to call into.

The protocol is a label. Emit `#metadata((...)) <feeds:item>` anywhere in
the bundle, with the metadata value shaped as an entry (the table above).
rheo compiles a whole project in one pass, so `items()` sees every beacon in
the bundle, not only the vertebra currently calling it:

```typst
#metadata((
  id: "idea:etal",
  title: "Et al.",
  page: "notes/etal.html",
  published: datetime(year: 2026, month: 1, day: 1),
  updated: datetime(year: 2026, month: 1, day: 2),
  categories: ("note",),
)) <feeds:item>
```

`item(...)` is the same thing without hand-writing the metadata dict:

```typst
#import "@rheo/feeds:0.1.0": item

#item(
  title: "Et al.",
  page: "notes/etal.html",
  published: datetime(year: 2026, month: 1, day: 1),
  updated: datetime(year: 2026, month: 1, day: 2),
  categories: ("note",),
)
```

and `items(filter:, label-name:)` is the source that reads them back:

```typst
feed(..., sources: (items(),))
```

The label is `feeds:item` by default; pass a matching `label-name` to both
`item(...)` and `items(label-name: ...)` to use one of your own. `filter`,
when given, is a predicate over the parsed value — the dict — not over the
beacon itself. Every beacon `items()` finds is validated on the spot: a value
that isn't a dictionary, or a dictionary with no non-empty `title`, fails the
build naming the label and what was found, rather than being silently
dropped.

Nothing in this repo emits this beacon today. `@rheo/rookery` does not, and
the demo's `notes.xml` goes through `ideas(tags:)` directly (above), not
through this protocol — the beacon exists for the case that recipe cannot
reach, not as a mechanism rookery itself uses.

## Per-entry overrides: no more `rheo-feed-title`/`rheo-feed-updated`

The retired generator let a vertebra override its own feed title or timestamp
with `rheo-feed-title`/`rheo-feed-updated` document variables, read back by
the plugin per output. There is no equivalent variable here — the same effect
comes from composing a small function over a built-in source (`spine()`,
`items()`, or any other) rather than annotating the page itself:

```typst
#import "@rheo/feeds:0.1.0": feed, configure, spine

#let with-overrides(s) = spine()(s).map(e => if e.page == "a.html" {
  e + (title: "Override", updated: datetime(year: 2026, month: 6, day: 1))
} else {
  e
})

#configure(feeds: (
  feed(
    path: "feed.xml",
    title: "My Site",
    base-url: "https://example.com",
    sources: (with-overrides,),
  ),
))
```

`e + (..)` merges just the keys being overridden into the entry `spine()`
already built for that page — every other field (`published`, `categories`,
`author`, ...) passes through untouched. This composes with any source, not
only `spine()`, and needs no `#set document` on the overridden page at all.
See `verify/override/` for a working fixture (bead rheo-packages-parity-qrd,
rows 2, 11, 12) — its `content/index.typ` is this exact pattern, adjusted only
to that fixture's own page names.

## Migrating from the retired Rust feed generator

`@rheo/feeds` pins parity against the Rust Atom generator retired from rheo
core (`rheo/crates/html/src/feed.rs`), but it is not a drop-in replacement.
Every `[html]` key and per-vertebra variable the old generator read has a home
here, but a few things are deliberate simplifications or genuine fixes, not
oversights.

### Config keys

| Retired (`rheo.toml`) | Here |
| --- | --- |
| `[html] feed_base_url` | the feed config's `base-url` |
| `[html] feed_title` | `title` |
| `[html] feed_author` | `author` |
| `[[html.feed_include]]` | no longer needed — a source already lists exactly what it lists |

### Per-vertebra variables

| Retired (`#let` in a vertebra) | Here |
| --- | --- |
| `#let rheo-feed-title = "..."` | the entry's `title` — usually `#set document(title: ...)`, which `spine()` reads back |
| `#let rheo-feed-updated = "..."` | `#set document(date: datetime(...))`, or a composed override — see "Per-entry overrides" above |
| `#let rheo-feed-exclude = true` | omit the page from every source's selection, or leave it undated — either drops it from the feed |

**`title` is required, with no fallback chain.** The retired generator fell
back from an explicit title, to the HTML spine's own title, to the project's
directory name. `feed(...)` here panics instead
(`@rheo/feeds: feed's \`title\` must be a non-empty string.`) — a deliberate
simplification someone migrating will come looking for, not a gap. See
`verify/no-title/` for a fixture that pins exactly this failure.

**An undated entry is dropped, not dated.** Atom requires `<updated>` (RFC
4287 §4.2.15), and Typst has no way to stat a compiled output file, so the
retired generator's mtime fallback has no equivalent here: a `spine()` entry
with no `#set document(date: ...)` — and no `published`/`updated` from
anywhere else — is silently excluded from the feed rather than timestamped
some other way. This doubles as the replacement for `rheo-feed-exclude`
above: an undated cover page or index simply never becomes a candidate entry.

**`<published>` is a genuine addition, not parity.** The retired generator
never emitted `atom:published` at all, mapping a page's date onto
`atom:updated` only. Here, an entry with a `published` value gets both
elements, with their own distinct values when they differ — see "Per-entry
overrides" above for a fixture where they do.

**`datetime.today()` is a trap.** It resolves to whatever date the build
happens to run on, so a vertebra dated with it produces a feed timestamp that
changes on every build — every reader re-surfaces that entry as "updated" on
every deploy, forever. Write a literal `datetime(year: ..., month: ...,
day: ...)` for a post's own `#set document(date: ...)` instead.

**A string date is rejected outright.** `rheo-feed-updated` took one; this
does not. `updated: "2026-01-01"` fails the build naming the field, rather
than being parsed on your behalf — the same reasoning as the trap above, since
a package guessing at a date format is a package getting it wrong quietly.

**Within one date, entries keep their source's order.** Dates from `spine()`
are day-granular — one `#set document(date: ...)` per vertebra — so two posts
published on one day are common, and the feed lists them in the order the
source produced them rather than reversing them. Where that matters, give the
two posts distinct dates rather than relying on source order.

## Local development

Pure Typst, no build step: `typst.toml`'s entrypoint points straight at
`src/lib.typ`, so editing `src/` takes effect immediately — no `dist/`, no
copy step to forget to re-run.

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo   # one time, per machine — symlinks the whole namespace
```

Symlink the whole `rheo` namespace from the repo root, not this package on its
own — under the namespace symlink, `ln -sfn` targeting an existing `feeds/`
directory writes the link *inside* it instead of replacing it, leaving a
self-referential `feeds/feeds`.

No package-specific devShell either: this repo's own root `flake.nix`/
`.envrc` already provide `just` and `typst`, and direnv finds them by walking
up from anywhere under this directory.

## Demo

`demo/` is a runnable proof of this package's headline capability: one
project, two Atom feeds built from different subsets of the same small site.

- `feed.xml` — the three dated posts under `demo/content/posts/`, selected by
  filtering the spine on each vertebra's handle (the `spine()` example
  above). One of them (`posts/deep/three.typ`) is nested a directory deep, to
  show the entry model doesn't care.
- `notes.xml` — the notes tagged `note` on `demo/content/notes.typ`, sourced
  through `ideas(tags:)` exactly as shown in "Sourcing from another package"
  above.

Needs an unreleased rheo (>= 0.6.0, currently the `feat/transclusion` line):
`<rheo-content>` transclusion and the `.rheo/` control-asset convention (both
of which this demo depends on, the second to mint its two feeds'
autodiscovery `<link>` tags) do not exist in 0.5.2. With that binary on `PATH`
(and this package reachable through the namespace symlink above, so
`@rheo/rookery` resolves from the same checkout):

```sh
rheo compile demo   # from the package root — or: just demo
./demo/check.sh     # asserts on the output — or: just check
```

OBSERVED (rheo `feat/transclusion`, this package's own build): both feeds
compiled to valid, non-empty Atom with disjoint entry sets. Every page's
`<head>` — the root vertebra, the nested one, and every minted note page
alike — carried both feeds' autodiscovery
`<link rel="alternate" type="application/atom+xml">` tags, minted once as
`.rheo/head.html` and spliced into every page rheo compiled, not just the one
vertebra that called `configure(...)`. `notes.xml`'s entries linked to
absolute URLs ending in `ideas/<slug>.html`, each matching a real minted file
on disk — including the note nested inside another note's body
(`ideas/alpha-inner.html`). Neither feed's `<content>` retained a
`<rheo-content>` placeholder: both had already been resolved to the real,
escaped HTML of the page they named.

## Verify

`verify/` pins the retired Rust generator's parity matrix (bead
rheo-packages-parity-qrd) that `demo/` above cannot exercise without changing
what that demo demonstrates: a `feed(...)` call missing `title` (must fail the
build), a project that imports the package but never calls `configure(...)`
(must mint nothing), and per-entry overrides composed over `spine()` (see
"Per-entry overrides" above). `demo/check.sh` itself pins the rest of the
matrix — feed/entry authorship, the feed title doubling as the autodiscovery
link's own `title=`, autodiscovery on every page, entry URL correctness
(including the `id`-is-not-a-url exception `notes.xml`'s rookery-sourced
entries take), an excluded page still being built, and an entry's timestamp
tracking its own `#set document(date: ..)`.

Same unreleased-rheo requirement as `demo/` above:

```sh
just verify   # builds its own fixtures — some of them are SUPPOSED to fail
```

`verify/EXPECTED.md` records the observed output of every row in the matrix,
row by row.
