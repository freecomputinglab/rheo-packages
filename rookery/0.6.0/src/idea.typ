// `#idea` itself, the two tag-sugar wrappers over it, and `#footnote`.
//
// `#idea` is the package: everything else either feeds it (state, urls, the
// permalink) or reads what it registered (windows, the outline, `#ideas`).
// `#footnote` lives here because a footnote belongs to the idea it was written
// in — the same rule the citation walk in `bib.typ` enforces.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "bib.typ": *
#import "transclusion.typ": *
#import "hyperlink.typ": *
#import "links.typ": *

// ---- #idea — the note itself: validation, registration, rendering ---------
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. An unnamed note steps a package-wide counter and takes the
// resulting sequence number as its id; a named note is pinned and does not
// perturb that counter. Either way the note gets: an `idea:<id>` Typst label on
// a hidden referenceable anchor, an HTML heading (only when `title` is given),
// and a registry entry carrying its raw body for `#window` to transclude later.
//
// Defined after `_outbound` above because it calls it at registration time, and
// a `#let` closure captures the scope visible AT DEFINITION time.

#let idea(level: 1, title: none, tags: (), exclude-tags: (), minted: none, updated: none, show-date: false, show-tags: false, ..args) = {
  // Same leniency as `#window`/`#ideas-outline`/`#ideas`: a single tag needs
  // no array ceremony. Without this, a bare string reached `v.tags.map(...)`
  // below and further down at render time — str has no `.map`, so the error
  // surfaced as an opaque method-not-found far from the actual mistake.
  //
  // As of 0.5.0 the normalized shape is a DICTIONARY: keys are tag names,
  // values are arbitrary Typst values, and a plain tag's value is `none`.
  // `_norm-tags` maps all four accepted forms onto it, so everything below
  // reads `.keys()` for the names and touches values only where it means to.
  _assert-tags(tags, "#idea's")
  let tags = _norm-tags(tags)
  let pos = args.pos()
  let (name, body) = if pos.len() == 1 {
    (none, pos.at(0))
  } else {
    (pos.at(0), pos.at(1))
  }
  let named = name != none
  let base = if named { _norm(name) } else { none }

  // ---- THE EXCLUSION GATE, and it sits HERE for a reason -------------------
  //
  // A note carrying an excluded tag is not hidden, it is ABSENT: no figure, no
  // metadata, no registry entry, no Typst label, no minted page, no `ideas()`
  // row, no search-index entry, no feeds beacon, no outline entry, no backlink.
  // See `_resolve-excluded` (base.typ) for the two channels, how they compose,
  // and why the list is an ARGUMENT rather than a `rookery.with()` state.
  //
  // ABOVE the `figure(kind: IK)` below, and that is the whole architecture of
  // this gate rather than a convenience. FIVE things walk for that marker
  // STRUCTURALLY, before realization — `_flatten`'s IK rule (transclusion.typ),
  // `_outbound` (links.typ), `_std-footnotes` and `_footnotes` (pure.typ), and
  // `_ideas-outline-data`'s `query()` (outline.typ) — so the marker cannot be
  // built and then suppressed. It has to never exist, which means the decision
  // has to be made with NO `#context`, which is why `_resolve-excluded` reads
  // `sys.inputs` and a plain argument instead of a state.
  //
  // TAG KEYS, so a VALUED tag excludes exactly as a plain one does: a tag
  // carrying metadata is no less a tag, the same rule `cls` below follows.
  let excluded = _resolve-excluded(exclude-tags)
  if tags.keys().any(t => t in excluded) {
    // TWO THINGS ONLY, and nothing else. Both are invisible.
    //
    // 1. THE COUNTER STILL STEPS for an unnamed note. Deliberate, not an
    //    oversight: an unnamed note takes its id from this counter, so skipping
    //    the step shifts every LATER unnamed note's id — `ideas/3.html` in the
    //    dev build would silently become `ideas/2.html` in the public one. One
    //    inert content node per excluded note buys stable URLs across every
    //    build variant, which is the whole point of a feature whose output is
    //    several builds of one source tree.
    //
    //    `counter.step()` RETURNS CONTENT: emitted as the block's value here,
    //    never inside a code block whose value is used — the trap recorded
    //    above at the non-excluded path's own `.step()`.
    //
    // 2. THE ID GOES ON `_excluded-ids`, named notes only — an unnamed note has
    //    no id anything could link to by name. That state is what lets
    //    `#window`/`#hyperlink`/`#idea-body` tell "deliberately excluded from
    //    this build" from "typo" and degrade instead of panicking. It holds
    //    STRINGS and nothing else: no body, no title, no tags, nothing to
    //    flatten or serialize, which is what keeps an excluded note free.
    //
    //    The `#context` wrapper is needed because `_pfx()` reads
    //    `_prefix.final()`. Safe here where it is fatal around the figure: this
    //    emits no content, so there is nothing for a structural walk to miss.
    return {
      if not named { counter("rheo-ideas-seq").step() }
      if named {
        context {
          // THE ID IS BUILT OUT HERE, NOT INSIDE THE `update` CLOSURE, and this
          // is the trap the non-excluded path below already records against
          // `doc-date`: an updater closure runs LAZILY, at `.final()` time,
          // where context is unknown — so a `_pfx()` call inside it fails with
          // "can only be used when context is known" the moment any reader
          // resolves this state. MEASURED here: `#window`'s own
          // `_excluded-ids.final()` was the reader that tripped it.
          let id = _pfx() + base
          _excluded-ids.update(r => if id in r { r } else { r + (id,) })
        }
      }
    }
  }

  // The marker wraps the whole idea. Its body carries the RAW body as
  // metadata so a later _flatten can render a nested idea's content without
  // re-registering or re-counting it.
  figure(kind: IK, supplement: none, [
    // `title`/`named`/`base`/`level`/`tags` let `_flatten`'s IK rule rebuild
    // this note's own heading+box when it is shown nested inside a
    // transcluded/minted parent, without re-running the context block below
    // (which would re-register and, for an auto id, re-step the counter).
    //
    // `tags` here is the DICTIONARY, as of 0.5.0 — `_flatten`'s IK rule and
    // `#ideas-outline` both read it back and must take `.keys()` for names.
    #metadata((body: body, title: title, named: named, base: base, level: level, tags: tags))
    // counter.step() RETURNS CONTENT: emit it here, never inside a code block
    // whose value is used, or it silently turns the id into content.
    #if not named { counter("rheo-ideas-seq").step() }
    #context {
      let id = if named {
        _pfx() + base
      } else {
        let n = counter("rheo-ideas-seq").get().first()
        _pfx() + str(n)
      }

      // Resolution order, most specific first: explicit minted:/updated:
      // arguments, then the containing document's own
      // `#set document(date:)`, else no date. MEASURED: a document with no
      // date set yields `auto`, NOT `none` — must be tested for explicitly.
      // Resolved HERE, outside the state.update() closure below: anything
      // contextual fails inside that closure with "can only be used when
      // context is known", since it runs lazily at `.final()` time.
      let doc-date = {
        let d = document.date
        if d == auto { none } else { d }
      }
      let resolved-minted = if minted != none { minted } else { doc-date }
      let resolved-updated = if updated != none { updated } else { resolved-minted }

      // `show-date` gates display only — the date is always RESOLVED and
      // stored on the registry record above, so a #window of this note can
      // still show it even when the note's own hat (here) does not.
      //
      // `resolved-updated`, NOT `resolved-minted`: the date a reader wants off the
      // top of a card is when the note was last touched. Nothing changes for a note
      // that never says `updated:`, because `resolved-updated` falls back to
      // `resolved-minted` one line above, which falls back to the document's own
      // date. `_window-content` reads the same field off the registry record.
      let date = if show-date and resolved-updated != none {
        resolved-updated.display("[year]-[month]-[day]")
      } else { none }

      // The note's CONTEXT: the handle of the page this `#idea` was written
      // in, captured HERE because this is the only moment anything knows it.
      // A minted note page is a separate `#document` and inherits nothing from
      // its origin, and `#window` can transclude a note into any number of other
      // pages — so "where was this written" has to be recorded at the call
      // site or it is gone.
      //
      // `state("rheo-handle")` is published per page by rheo's own
      // `rheo-page-init`. `.get()`, not `.final()`: the point is the handle
      // HERE, at this position in the spine, not wherever the document ends.
      // Non-str (a plain `typst compile`, where nothing publishes it) means no
      // context to record — `.marrow.typ`, the only reader, does not run there
      // anyway.
      let handle = state("rheo-handle").get()
      let origin = if type(handle) == str { handle } else { none }

      // Store the FLATTENED body plus the title, resolved dates and origin, so
      // a #window is pure presentation and any number of windows cost nothing, and
      // `#hyperlink`'s ref-mode can render a note's title without re-deriving
      // it. A duplicate EXPLICIT id only errors if something
      // observes the registry (e.g. #window or a ref) — an identical
      // re-insertion is a re-emission, not a collision.
      // A Typst footnote in here is one this package cannot claim: its body
      // would go to the page's endnote section instead of this idea's block,
      // and the build would otherwise SUCCEED while doing it. Checked at
      // registration rather than at render, so it runs once per idea however
      // many windows transclude it, and so the error names the authoring
      // mistake rather than firing from whatever page happens to window the
      // note.
      if _std-footnotes(body).len() > 0 {
        panic(
          "@rheo/rookery: `#footnote` inside an idea is Typst's, not rookery's — "
            + "its body would land in the page's endnote section instead of this "
            + "idea's Footnotes block. Add `footnote` to your import: "
            + "`#import \"@rheo/rookery:0.6.0\": idea, footnote`.",
        )
      }

      // Outbound links, filtered to real note ids and deduped, with a
      // self-link dropped — a note is not its own backlink. Walked from the
      // RAW body, before `_flatten`: flattening rewrites `#window` markers into
      // permalinks, which would turn every transclusion into an
      // indistinguishable `link` and lose the ones nested inside other notes.
      let links = _outbound(body)
        .filter(t => t.starts-with(_pfx()) and t != id)
        .dedup()

      // `raw` is the body BEFORE flattening, kept alongside the flattened one
      // so a `#window` with a nested-window budget can re-flatten at a smaller
      // depth (see `_body-at`). Re-flattening the FLATTENED body would be
      // wrong: its WK markers have already been reduced to permalinks by the
      // depth-0 rule baked into it, so there would be nothing left to expand.
      //
      // `tags` is the normalized DICTIONARY, stored as `#idea` received it —
      // already deduped, because a `tagged-idea` wrapper prepends its own tag
      // via `_dedup-tag` before calling in. TAGS ARE UNORDERED as of 0.5.0:
      // key order is unspecified and nothing may depend on it.
      //
      // It takes part in the identity comparison below, and the dictionary
      // changes what that catches. MEASURED: typst dictionary `==` is
      // ORDER-INSENSITIVE, so two pins of one id whose tags differ only in
      // order no longer collide — which is correct now that order carries no
      // meaning. Two whose tag VALUES differ do collide, exactly as they
      // already did when `raw` or `origin` differed.
      let rec = (
        title: title,
        raw: body,
        body: _flatten(body),
        minted: resolved-minted,
        updated: resolved-updated,
        origin: origin,
        links: links,
        tags: tags,
      )
      _registry.update(r => {
        let existing = r.at(id, default: none)
        if id in r and existing != rec {
          panic(
            "@rheo/rookery: duplicate note id " + id + " — already registered"
              + (if existing.origin != none { " in " + existing.origin } else { "" })
              + ", registered again" + (if origin != none { " in " + origin } else { "" })
              + ". A pinned id must be unique across the whole rookery.",
          )
        }
        r.insert(id, rec)
        r
      })

      // Hidden referenceable anchor. VERIFIED: a locally scoped
      // `show ...: none` still hides it while leaving it referenceable, in-page
      // AND cross-page; it exports as <span id="loc-N">, and typst's own bundle
      // export turns a cross-vertebra #link(label(id)) into
      // ../<page>.html#loc-N.
      {
        show figure.where(kind: "rheo-idea-anchor"): none
        [#figure([], kind: "rheo-idea-anchor", supplement: none)#label(id)]
      }

      let ttl = if title == none { none } else { title }
      // CLASSES COVER EVERY KEY, valued tags included: `.idea-tag-<key>` is the
      // hook a project styles a tag by, and a tag that carries metadata is no
      // less a tag for it. Only the PILLS below are restricted to flat tags.
      let cls = ("idea",) + tags.keys().map(l => "idea-tag-" + l)
      // The flat tags — those whose value is `none`. This is what `show-tags:`
      // renders as pills: a valued tag's name alone says nothing useful in a
      // pill (`depends-on` with no dependencies shown), so a package carrying
      // metadata in tags renders it it own way instead of polluting the hat.
      let flat-tags = tags.pairs().filter(p => p.at(1) == none).map(p => p.at(0))
      if _target() == "html" or _target() == "epub" {
        // The permalink is the ONLY way to discover an auto-generated id —
        // there is no `show heading` rule and no template to hook into, so
        // `#idea` emits it directly, always (even with no title), showing
        // the FULL `idea:name` id so it is copy-pasteable straight into
        // `#window("...")`. `#window` renders the identical affordance in its own
        // summary; both go through `_permalink-tab`.
        //
        // ABOVE the heading, not inside it: the id is the card's top rule (see
        // `_permalink-tab` and `.idea-tab`), so a titleless note needs no
        // special case — the tab is the same either way. The title keeps its
        // span, which nothing styles by default: it stays a hook a project can
        // reach for, and `#window`'s summary wraps its title the same way.
        //
        // THE DATE IS IN THE TAB TOO, at its far right, and no longer a second
        // child of the heading. It belongs to the frame rather than to the
        // sentence: read inside the `<h2>` it was a subtitle, and it made a
        // titleless note's heading non-empty for nothing (see the note below on
        // `h*.idea:empty`).
        //
        // The heading element survives even with NO children — a titleless note.
        // Its `id` attribute is the note's in-page anchor, the destination of every
        // `@idea:etal` fragment link, so dropping the element would break them;
        // `h*.idea:empty` in the stylesheet is what keeps it from taking any space,
        // and it now applies to a dated titleless note as well.
        let header = _head(
          _permalink-tab(id, tags: if show-tags { flat-tags } else { () }, date: date),
          html.elem(
            "h" + str(level + 1),
            attrs: (id: id, class: cls.join(" ")),
            if ttl == none { [] } else {
              html.elem("span", attrs: (class: "idea-title"), ttl)
            },
          ),
        )
        // Header and body wrap together in one card, HTML/EPUB only — no box
        // for a paged target. The box classes mirror `cls` (tags included)
        // so a tag can style the whole card, not just the heading; the
        // heading's own class list (above) is untouched for existing
        // stylesheets.
        let box-cls = ("idea-box",) + tags.keys().map(l => "idea-tag-" + l)
        _sweep-block()
        // Bracketed so a link written INSIDE this note counts as the note's,
        // not as its page's — see `_edge`.
        //
        // THE REFERENCES BLOCK GOES INSIDE THE CARD, beside the footnotes block
        // rather than under the card's floor. Both are apparatus for this note,
        // and the card's `border-left` and `padding-left` are what say so: a
        // sibling gets neither, so its "References" heading hung flush against
        // the page's own margin while the footnotes one line above it sat at the
        // note's text margin. MEASURED in `demo/pure/build/root.html`: the card
        // closed, then `<div class="idea-references">` opened outside it.
        // Document order is unchanged by the move, which is what leaves Typst's
        // POSITIONAL citation partitioning alone — the block still follows the
        // body, so it still claims exactly this note's citations.
        _bracket(
          html.elem(
            "div",
            attrs: _themed((class: box-cls.join(" "))),
            header + _footnoted(body) + _refs-block(_own-cited-keys(body)),
          ),
          IK,
        )
      } else {
        // `align(start)`, and it is load-bearing: this whole branch renders
        // INSIDE the `figure(kind: IK)` that marks the note, and a Typst
        // figure CENTRES its body. On html/epub that is inert — the figure
        // exports as `<figure>` and CSS decides — but on a paged target it
        // centred every note in the document: headings, prose, raw blocks and
        // all. MEASURED on rookery.ohrg.org's PDF, and reproduced down to a
        // bare `#figure(kind: "k", supplement: none)[long paragraph]`, which
        // centres while the same text outside one does not. A rheo project
        // with no notes in it was left-aligned, which is what placed the
        // defect here rather than in rheo.
        //
        // `start`, not `left`: it follows text direction, so an RTL document
        // is not forced the wrong way round. The figure is not optional — it
        // is the marker `_flatten`, `_outbound` and `#ideas-outline` all find
        // notes by — so undoing its alignment is the fix, not removing it.
        // The paged target needs these just as much as HTML does, and it is
        // not cosmetic there: a citation with no bibliography anywhere is a
        // HARD ERROR (`label <key> does not exist in the document`), so a
        // combined PDF fails to build without them. MEASURED.
        _sweep-block()
        _bracket(align(start, {
          if ttl != none { heading(depth: level, ttl) }
          if date != none { text(gray, date); linebreak() }
          _footnoted(body)
        }) + _refs-block(_own-cited-keys(body)), IK)
      }
    }
  ])
}

// ---- #tagged-idea / #tags-of / #tag-value — an idea's tags ----------------
//
// `tagged-idea` is a FACTORY: it returns an `#idea` variant that prepends one
// tag to whatever the caller passed. Define your own vocabulary with it —
//
//   #let note = tagged-idea("note")
//   #let todo = tagged-idea("todo")
//   #let claim = tagged-idea("claim")
//
// — and `#note("x")[...]` is exactly `#idea("x", tags: (note: none))[...]`.
// No new parameter on `#idea`, no recognised set of tags, no subclassing.
//
// REPLACES the hardcoded `note`/`todo` this package exported through 0.4.1.
// Two names could never be the right two, and a project or a package wanting a
// third had to reimplement the forwarding below. `@rheo/rookery-todos` builds
// its whole `#todo`/`#epic` surface on this.
//
// The returned function forwards every other argument (level, title, minted,
// updated, show-date, show-tags) and the POSITIONAL SINK untouched, so
// `#note[body]`, `#note("name")[body]` and `#note(<name>)[body]` all work
// exactly as the `#idea` forms do.
//
// `value:` is the default this factory binds for its own tag, for a wrapper
// whose tag means something richer than its own presence. A CALLER'S OWN VALUE
// FOR THAT TAG WINS OUTRIGHT — `#todo("x", tags: (todo: (state: "open")))`
// keeps `(state: "open")` — and there is no deep merge between the two.
// `_dedup-tag`'s "already a key" guard is what implements that.
//
// THE TRAP, do not reintroduce: `#let note = idea.with(tags: (note: none))`.
// An explicit `tags:` argument at the call site OVERRIDES a value bound by
// `.with()`, so `#note("x", tags: ("draft",))` would silently drop "note" —
// the tag the caller chose `#note` for in the first place. The closure below
// exists precisely because `.with()` cannot express "merge, don't replace".
// `exclude-tags:` IS TAKEN HERE TOO, AND IT IS REQUIRED, not a nicety. This
// factory's returned closure calls the `idea` captured in PACKAGE scope, so a
// project writing `#let idea = idea.with(exclude-tags: E)` does NOT thereby
// reach `#let note = tagged-idea("note")` — that wrapper would keep hatching
// the very notes the project asked to have excluded, which is the worst failure
// shape available: a silently incomplete exclusion in a published build. Hence
// the documented project pattern is two bindings sharing one list:
//
//   #let EX = ("protected", "private")
//   #let idea = idea.with(exclude-tags: EX)
//   #let note = tagged-idea("note", exclude-tags: EX)
//
// It is named on the RETURNED CLOSURE as well, defaulting to the factory's own
// value, and that is deliberate: without it a caller writing
// `#note("x", exclude-tags: (..))` would land the argument in `..args` and
// Typst would error on a duplicate named argument. With it, the factory binding
// is the default and a call site can still override.
#let tagged-idea(tag, value: none, exclude-tags: ()) = (
  tags: none,
  exclude-tags: exclude-tags,
  ..args,
) => idea(
  tags: _dedup-tag(tag, tags, value: value),
  exclude-tags: exclude-tags,
  ..args,
)

//
//   #context tags-of("etal")   // -> ("note", "draft")
//
// Takes a bare name, a full id or a Typst label — whatever `_norm` accepts,
// which is the same set of forms `#window` and `#hyperlink` take. Returns the
// note's tag NAMES as a flat array, and `()` both for an untagged note and for
// an id that does not exist — a missing note is not an error here, because a
// caller asking "what is this tagged" is filtering, not dereferencing.
//
// EVERY key, valued tags included: a tag that carries metadata is still a tag,
// and this is the "what is this tagged" question. KEY ORDER IS UNSPECIFIED as
// of 0.5.0 — tags are unordered, and nothing may depend on the sequence.
//
// The VALUES are deliberately not here. `tag-value` below fetches one, and
// `tag-data` (data.typ) fetches the whole store in bulk.
//
// Must be called INSIDE a `#context` block: it reads `_registry.final()`. It
// is not itself a context function, because a context function may only
// return content and the whole point here is to return data.
#let tags-of(name) = {
  let id = _pfx() + _norm(name)
  _registry.final().at(id, default: (:)).at("tags", default: (:)).keys()
}

// One tag's VALUE on one note:
//
//   #context tag-value("etal", "priority")            // -> 1
//   #context tag-value("etal", "nope", default: 4)    // -> 4
//
// Takes the same name forms `tags-of` takes. Returns `default` when the note
// does not exist, or exists without that key — a missing note is not an error,
// for the same reason it is not one in `tags-of`.
//
// A PLAIN TAG'S VALUE IS `none`, which is indistinguishable from `default:
// none` on a key that is absent. Ask `tags-of` (or `tag-data`) when the
// question is presence rather than value; this function answers "what is it
// set to", and a plain tag is set to nothing.
//
// Must be called INSIDE a `#context` block, same as `tags-of`.
#let tag-value(name, key, default: none) = {
  let id = _pfx() + _norm(name)
  _registry.final().at(id, default: (:)).at("tags", default: (:)).at(key, default: default)
}

// ---- #footnote — shadows Typst's, scoped to the enclosing idea ------------
//
// Import it alongside `#idea` and write footnotes exactly as before:
//
//   #import "@rheo/rookery:0.6.0": idea, footnote
//   #idea("etal")[A claim#footnote[The evidence.] worth qualifying.]
//
// Emits nothing on its own — it is an invisible marker. Inside an idea,
// `_footnoted` claims it, numbers it against that idea and lists its body in
// the idea's own Footnotes block. Outside one, the document-wide rule
// `#show: rookery` installs falls back to `std.footnote`, so a footnote in
// ordinary page prose behaves exactly like Typst's: page-wide numbering, body
// in the page's endnote section.
//
// It must NOT call `std.footnote`, step a counter, or emit a `<sup>` — all of
// that belongs to whichever show rule claims the marker, and doing any of it
// here would put a real footnote element in the document that nothing can
// then remove (see the note on FNK above).
#let footnote(body) = [#metadata((rookery-fn: body))<rkfn>]
