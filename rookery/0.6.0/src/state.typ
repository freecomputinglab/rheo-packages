// The document-wide state this package publishes and reads back.
//
// One module because these share a discipline rather than a subject: each is a
// `state` (or a `counter`) written once by `#show: rookery` or by a note as it
// registers, and read everywhere else through `.final()`. The comments on the
// individual updates record which ones need the `_ =>` wrapper and why — that
// is the trap this grouping exists to keep in one place.
//
// Imports `base.typ` only.

#import "base.typ": *

// ---- Label prefix — configurable, document-wide ---------------------------
//
// A note's id is `<prefix>:<name>`, `idea:` by default; `#show: rookery` (at
// the bottom of this file) changes it.
//
// The prefix is document-wide STATE rather than a parameter on `#idea`,
// because four separate places have to agree on it — `#idea` (minting the
// label), `#window` (looking one up), `_note-file` (deriving a minted page's
// slug from an id) and `.marrow.typ` (minting those pages) — and only
// `#idea`'s call site could ever pass an argument. One wrong reader and the
// id it builds simply does not exist.
//
// Read with `.final()`, NOT `.get()`. `#show: rookery` is applied per FILE
// (imports are per-file), so under rheo a spine sets the same prefix once per
// vertebra; a vertebra that forgot the template would, under `.get()`, mint
// `idea:` ids in the middle of an otherwise `note:` document, and a `#window`
// reaching across that boundary would panic on an id that was never
// registered. `.final()` collapses the whole document to ONE prefix (last
// writer wins), so every reader agrees no matter which file it sits in.
//
// EVERY caller of `_pfx` is therefore inside a `context` block already —
// `#idea`'s deferred body, `#window`, `_note-href` via `#idea`/`#window`/
// `#hyperlink`, and `.marrow.typ`'s own `#context`.
#let _prefix = state("rheo-idea-prefix", "idea")
#let _pfx() = _prefix.final() + ":"
// ---- Window depth — how far a nested `#window` unfurls ---------------------
//
// THE SCALE COUNTS LEVELS OF TRANSCLUSION, AND `0` IS NOT THE DEFAULT:
//
//   0   transcludes NOTHING. A `#window` renders as the note's title linked to
//       the note's own page — no summary, no disclosure, no body (see
//       `#window`'s depth-0 branch).
//   1   the default, and today's behaviour: the note renders once, and a
//       `#window` found INSIDE it collapses to a bare permalink (`_flatten`'s
//       WK rule).
//   n   unfurls n-1 further levels of nested windows, collapsing at the nth.
//
// Expanding a nested window with no budget is what makes a cycle — a
// self-window, or A-windows-B/B-windows-A — re-expand forever, and the budget
// is what makes bounded expansion safe. So every comparison against a depth in
// this file asks `> 1`, never `> 0`: the question is always "may I unfurl a
// window found INSIDE this one", and one level of that budget is already spent
// on rendering the window itself.
//
// MIGRATION off the old scale, where `0` was the default and `n` unfurled `n`
// nested levels: add one. A project that set `window-depth: 2` wants `3`.
//
// Document-wide state for the same reason `_prefix` is (`#show: rookery` is
// applied per FILE, and a note written in one vertebra can be windowed from
// another), read with `.final()` so every reader agrees. `#window`'s own
// `depth:` argument overrides it per call site.
#let _window-depth = state("rheo-idea-window-depth", 1)
// ---- The bibliography — one for the whole rookery -------------------------
//
// Configured on the template, taking Typst's own `#bibliography` arguments so
// there is nothing new to learn:
//
//   #show: rookery.with(bibliography: arguments(
//     bytes(read("refs.bib")),
//     style: "chicago-author-date",
//   ))
//
// BYTES, NOT A PATH, and it is not a stylistic choice. Typst resolves a path
// relative to the FILE THE CALL APPEARS IN, and every call this package makes
// appears inside the package: `bibliography("refs.bib")` spread in here looks
// for the file next to `lib.typ`, and so does `read`. MEASURED —
// `file not found (searched at .../rookery/0.1.0/src/refs.bib)`. `bytes` carries
// its data rather than a path, so the author's own `read()` resolves at the
// author's own call site and everything downstream just works. `bytes` is one
// of the source types Typst's own `#bibliography` accepts, so this is still
// literally its argument list.
//
// Document-wide state for the same reason `_prefix` is: `#show: rookery` is
// applied per FILE, and a note written in one vertebra can be windowed from
// another. Read with `.final()` so every reader agrees.
//
// Holds an `arguments` value or `none`, spread straight into `bibliography(..)`
// by the beads that render the blocks.
#let _bib = state("rheo-idea-bib", none)

// Every key in the configured source, as an array of strings.
//
// A KEY-EXISTENCE CHECK, NOT A PARSER. It reads no author, no date and no
// title, and nothing downstream may depend on it for rendering — Typst formats
// every citation and every bibliography entry. Its ONLY job is answering "does
// this idea cite anything", so an idea that cites nothing emits no empty block.
// Growing this into a BibTeX parser is an explicit non-goal: the package reuses
// Typst's bibliography infrastructure rather than reimplementing it.
#let _bib-keys() = {
  let cfg = _bib.final()
  if cfg == none { return () }
  let src = cfg.pos().first()
  let sources = if type(src) == array { src } else { (src,) }
  let keys = ()
  for s in sources {
    let text = str(s)
    // Format is detected from the CONTENT, since bytes carry no filename. A
    // Hayagriva file is a YAML mapping and has no `@type{` entry headers; a
    // BibTeX file is nothing but those.
    let entries = text.matches(regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,"))
    if entries.len() > 0 {
      keys += entries.map(m => m.captures.first())
    } else {
      // Hayagriva is a mapping of key -> entry, so its keys ARE the keys.
      keys += yaml(s).keys()
    }
  }
  keys
}

#let _cited-keys(body) = {
  let keys = _bib-keys()
  if keys.len() == 0 { return () }
  _cite-walk(body).filter(k => k in keys)
}
// ---- Minted-page configuration: template, syndication, index page -------
//
// `.marrow.typ` mints one standalone page per note, and those pages are
// separate `#document`s spliced in at the BUNDLE ROOT — outside every
// vertebra, and so outside whatever `#show:` the project applies to its own
// pages. A minted page therefore has no site chrome unless the project hands
// one over, which is what this is for:
//
//   #show: rookery.with(idea-page-template: my-idea-page)
//
//   #let my-idea-page(id: none, note: (:), doc) = {
//     show: chrome.with(current-page: id)
//     doc
//   }
//
// `.marrow.typ` calls it as `tpl(id: <id>, note: <registry record>, page)`,
// wrapping the whole minted page — heading, body and footer — so the template
// sees exactly what a vertebra's own `#show:` would.
//
// WHY A STATE HOLDING A FUNCTION, which nothing else in this package does:
// the project cannot reach `.marrow.typ` and `.marrow.typ` cannot reach the
// project. Marrow's text is inlined into rheo's synthesized bundle root, so a
// relative `#import "template.typ"` there would resolve against the PROJECT
// root and, worse, name a file only one particular project has. A state is
// the only channel that runs from a vertebra to the bundle root. VERIFIED on
// typst 0.15.1 that a state can hold a function, that `.final()` returns it
// callable, and that the document still converges.
//
// Register a NAMED top-level function, not an inline closure built inside the
// template that installs it: a fresh closure per vertebra puts a different
// value on the state timeline for each one, and `.final()` is then whichever
// file happens to be last. A named binding is one value however many
// vertebrae reference it.
//
// `.update(_ => f)`, never `.update(f)` — `state.update` treats a FUNCTION
// argument as an updater to call on the old value, so the plain form would
// call the project's template with the old state as its only argument and
// store the result. The wrapper is what makes the function a value.
#let _idea-page-template = state("rheo-idea-page-template", none)

// Whether `.marrow.typ` should emit a `<feeds:item>` beacon alongside each
// minted note page — see the "syndicate" comment in `.marrow.typ` for the
// contract. A plain value, not a function, so this carries the same wrapper
// discipline as `_idea-page-template` in reverse: `.update(syndicate)`, NOT
// `.update(_ => syndicate)` — the `_ =>` wrapper exists only to stop
// `state.update` from calling a FUNCTION value as an updater, and a bool is
// not one.
#let _syndicate = state("rheo-idea-syndicate", false)

// Whether `.marrow.typ` should mint an `ideas/index.html` landing page for the
// whole rookery. Same wrapper discipline as `_syndicate` above and for the same
// reason: a bool is not a function, so `.update(index-page)` is right and
// `.update(_ => index-page)` would store a closure.
//
// DEFAULT OFF. A project with its own index — ohrg.org's homepage is a
// `#window(tags: "post", ..)`, weeknotes' is the same — must not find a second
// one published under it because it upgraded the package.
#let _index-page = state("rheo-idea-index-page", false)
// ---- The registry, and a footnote's numbering within its idea -----------
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. An unnamed note steps a package-wide counter and takes the
// resulting sequence number as its id; a named note is pinned and does not
// perturb that counter. Either way the note gets: an `idea:<id>` Typst label on
// a hidden referenceable anchor, an HTML heading (only when `title` is given)
// carrying that id and an `idea`/`idea-tag-<tag>` class list, and a registry
// entry other beads (#window, #hyperlink) read from.
#let _registry = state("rheo-ideas", (:))

// ---- The excluded ids — "deliberately absent", not "never existed" ---------
//
// Every NAMED note `#idea`'s exclusion gate dropped from this build, as a plain
// ARRAY OF STRINGS of full ids. No bodies, no titles, no tags, no dates —
// nothing to flatten and nothing to serialize, which is what keeps an excluded
// note genuinely free rather than merely invisible. See `_resolve-excluded`
// (base.typ) for what excludes a note and why the decision is context-free.
//
// ITS ONLY JOB is letting a consumer tell a note the build removed on purpose
// from a note that never existed. `#window`, `#hyperlink` and `#idea-body`
// otherwise treat both identically and panic `unknown note`, so turning on an
// exclusion would break the public build wherever a surviving note or page
// links to a removed one. With this, they render nothing (or the bare id) for an
// excluded target while a genuine TYPO still panics, which is the distinction
// worth having.
//
// UNNAMED NOTES ARE NOT HERE, and cannot be: an auto-numbered note has no id
// anything could name it by, so there is nothing for a consumer to look up.
//
// Read with `.final()`, like `_registry` and `_prefix` above and for the same
// reason: a note may be excluded in one file and linked from another, and
// `.final()` is what makes every reader agree regardless of which file it sits
// in.
//
// `.update(r => ..)` is the UPDATER form and is correct here — the value is an
// array, not a function, so the `_ =>` wrapper the states below carry (see
// `_idea-page-template`) is neither needed nor wanted.
#let _excluded-ids = state("rheo-ideas-excluded", ())

// Stepped ONCE per rendered idea box. It exists only so two renderings of the
// SAME body on one output page (its own `#idea`, plus a `#window` on it) get
// distinct HTML ids. Document-wide and monotonic — uniqueness within a page is
// all that is asked of it, so it never resets.
#let _fn-block = counter("rheo-idea-fn-block")

// The visible footnote number, reset to 0 at the start of every idea box. Two
// ideas on one page may each legitimately carry a footnote "1" — that is the
// point of the feature, not a collision.
#let _fn-seq = counter("rheo-idea-fn")

// The inline reference. `b` is this rendering's block number, `n` the
// footnote's number within it; together they name both anchors.
#let _fn-ref(b, n) = {
  let tag = str(b) + "-" + str(n)
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "sup",
      attrs: (class: "idea-fn-ref", id: "fnref-" + tag),
      html.elem("a", attrs: (href: "#fn-" + tag), str(n)),
    )
  } else {
    super(str(n))
  }
}

// The block itself, at the end of the idea's body. Empty content when there is
// nothing to list: an idea with no footnotes emits no block and no heading.
#let _fn-block-html(notes, b) = {
  if notes.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "div",
      attrs: (class: "idea-footnotes"),
      html.elem("h4", attrs: (class: "idea-footnotes-title"), [Footnotes])
        + html.elem(
          "ol",
          attrs: (class: "idea-footnote-list"),
          notes
            .enumerate()
            .map(((i, body)) => {
              let tag = str(b) + "-" + str(i + 1)
              html.elem(
                "li",
                attrs: (class: "idea-footnote", id: "fn-" + tag),
                html.elem(
                  "a",
                  attrs: (class: "idea-fn-backlink", href: "#fnref-" + tag),
                  "^",
                )
                  + " "
                  + body,
              )
            })
            .join(),
        ),
    )
  } else {
    // Paged target: no ids and no anchors, neither of which means anything in
    // a PDF. The block still renders, so an idea reads the same everywhere.
    [*Footnotes*] + enum(..notes)
  }
}
