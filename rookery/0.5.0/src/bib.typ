// Bibliographies: the block an idea renders, and the walk that decides which
// citations are that idea's to render.
//
// The walk is the subtle half. A citation belongs to the idea it was written
// in, which means a nested idea or window CLAIMS the citations under it, and a
// footnote does not — the comments here record what each of those cost to get
// right.

#import "base.typ": *
#import "state.typ": *

// ---- References blocks ----------------------------------------------------
//
// Typst partitions citations POSITIONALLY: each `#bibliography` claims the
// citations nearest-following it. That is the whole mechanism — one
// bibliography emitted after an idea's body claims exactly that idea's
// citations, with no key filtering needed and nothing to keep in sync.
//
// Builds the call from `_bib`'s parts rather than spreading and adding
// `title:` on top: passing a named argument the spread already carries is a
// duplicate-argument error the moment an author configures their own title.
#let _bib-call(title) = {
  let cfg = _bib.final()
  let named = cfg.named()
  named.insert("title", title)
  bibliography(..cfg.pos(), ..named)
}

// ---- Whose citation is it, when a note contains another block? ------------
//
// `_cited-keys` answers "what does this content cite", which is a CONTENT
// question. An idea's own block needs a narrower, POSITIONAL one: "what will
// still be unclaimed by the time my block renders".
//
// A nested `#idea` or `#window` emits a references block of its own, INSIDE the
// enclosing idea's body and therefore BEFORE the enclosing idea's block. Typst
// partitions positionally, so that inner block sweeps up everything preceding
// it — including the enclosing idea's own citations. MEASURED before this fix,
// tracing byte offsets in a minted page for
// `#idea("outer")[Outer cites @beta2021. #window("multi")]`:
//
//      191  CITE Beta 2021       <- Outer's OWN citation
//      684  idea-references      <- the WINDOW's block; claimed all of it
//      998  idea-references      <- Outer's own block, nothing left
//
// and that last one rendered `<h2>References</h2><ul></ul>` — a visible empty
// heading, which is precisely what `_cited-keys` exists to prevent, arriving
// through ordering rather than through content.
//
// So scan the body in order, recording citations AND the nested blocks that
// will claim them. Both IK and WK count: a nested idea emits a block just as a
// window does.
#let _cite-scan(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == ref { return ((kind: "cite", key: str(node.target)),) }
  if node.func() == cite { return ((kind: "cite", key: str(node.key)),) }
  // A `#window` builds its `figure(kind: WK)` INSIDE a `context` block, so at
  // raw-body time there is no figure here to find — only the announce marker
  // `#window` emits up front for exactly this kind of walk (`_outbound` reads
  // the same one). MEASURED: scanning for the WK figure alone missed every
  // window and left the empty heading in place.
  if node.func() == metadata {
    if type(node.value) == dictionary and "rookery-window" in node.value {
      return ((kind: "claim", via: "window"),)
    }
    // `#footnote` carries its body as a metadata PAYLOAD, so a citation written
    // inside one is reachable ONLY through the value. Descend into it: "a
    // citation belongs to the idea in which you write it, just as footnotes do"
    // is what the documentation promises, and a footnote is written in this
    // idea. MEASURED before this branch existed, on an idea whose only citation
    // sat inside `#footnote[...]`: the author-date marker rendered, no
    // `.idea-references` block was emitted at all, and the reader saw
    // `(Wajcman 2009)` with nothing anywhere on the site saying what it cited.
    //
    // Counted ONCE, not twice. `_own-cited-keys` scans the RAW body; the
    // rendered footnote content `_footnoted` appends is never fed back through
    // it, so the payload is the only place this citation is ever seen.
    if type(node.value) == dictionary and "rookery-fn" in node.value {
      return _cite-scan(node.value.rookery-fn)
    }
    return out
  }
  // A nested `#idea`, by contrast, IS a figure by the time it lands in the
  // enclosing body: `#idea` returns one directly rather than deferring it.
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) {
    return ((kind: "claim"),)
  }
  if node.has("children") { for k in node.children { out += _cite-scan(k) } }
  else if node.has("body") { out += _cite-scan(node.body) }
  else if node.has("child") { out += _cite-scan(node.child) }
  out
}

// The keys an idea's own block will actually still own.
//
// Everything after the LAST nested claimant, not the first: each nested block
// claims in turn, so it is the final one that decides what is left. A citation
// written between two nested windows belongs to the second, not to the idea.
//
// `windows-claim: false` for a context where nested windows COLLAPSE instead of
// rendering — a minted page, or any `_flatten` scope out of depth budget. A
// collapsed window is a bare permalink: it emits no block and therefore claims
// nothing, so the idea keeps its own citations after all. MEASURED when this
// was missed: `ideas/before.html` cited Beta 2021, emitted no bibliography at
// all, and its citation fell back onto an unrelated minted page's block — the
// same contamination `rookery-bib-minted-m6h` had just fixed, reintroduced from
// the other side. A nested `#idea` always renders its own box and block, so it
// stays a claimant either way.
#let _own-cited-keys(body, windows-claim: true) = {
  let keys = _bib-keys()
  if keys.len() == 0 { return () }
  let scan = _cite-scan(body)
  let last = -1
  for (i, e) in scan.enumerate() {
    if e.kind == "claim" and (windows-claim or e.at("via", default: none) != "window") {
      last = i
    }
  }
  scan.slice(last + 1).filter(e => e.kind == "cite").map(e => e.key).filter(k => k in keys)
}

// One idea's references. Empty content when the idea cites nothing, so no
// stray "References" heading appears — that is what `_own-cited-keys` is for.
#let _refs-block(keys, id: none) = {
  if _bib.final() == none or keys.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    let attrs = (class: "idea-references")
    if id != none { attrs = attrs + (id: id) }
    html.elem("div", attrs: attrs, _bib-call([References]))
  } else {
    _bib-call([References])
  }
}

// Claims any unclaimed PROSE citations that precede an idea.
//
// Without it they leak into that idea's list, the partition being positional
// and the idea's own bibliography being the nearest one following them.
// MEASURED before the fix: an idea's block listed both the prose citation
// written above it and its own.
//
// UNCONDITIONAL, and `title: none`. Whether unclaimed prose citations precede
// a given idea cannot be determined from inside `#idea` — it never sees page
// prose — and it cannot be determined by querying either: deciding whether to
// emit a bibliography from `query(cite)` is CIRCULAR and hard-errors, because
// with none yet emitted the refs never resolve to cites, so the query finds
// nothing, so nothing is emitted, so the refs fail. MEASURED. A title-less
// bibliography with nothing to list renders `<section><ul></ul></section>` —
// no heading, nothing visible — which is what makes always emitting it safe.
#let _sweep-block() = {
  if _bib.final() == none { return [] }
  if _target() == "html" or _target() == "epub" {
    html.elem("div", attrs: (class: "idea-page-refs"), _bib-call(none))
  } else {
    _bib-call(none)
  }
}

// Wrap one idea box's body: number its markers locally, then append the block.
//
// The `show FNK:` rule installed here is NESTED relative to the document-wide
// fallback `#show: rookery` installs, and the nested rule wins — MEASURED. It
// also travels with the content wherever it is later inserted, the same way
// `_flatten`'s `show ref: hyperlink` does, which is what makes a transcluded
// body number its footnotes against the window's own block rather than the
// origin idea's.
//
// Returns `body` untouched when there is nothing to number, so `_fn-block` is
// not stepped for an idea with no footnotes.
#let _footnoted(body) = {
  let notes = _footnotes(body)
  if notes.len() == 0 { return body }
  _fn-block.step()
  context {
    let b = _fn-block.get().first()
    _fn-seq.update(0)
    {
      show FNK: it => {
        _fn-seq.step()
        context _fn-ref(b, _fn-seq.get().first())
      }
      body
    }
    _fn-block-html(notes, b)
  }
}
