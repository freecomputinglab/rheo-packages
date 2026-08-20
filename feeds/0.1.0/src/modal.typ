// @rheo/feeds — the subscribe modal
//
// The ONLY part of this package that emits page markup. Everything else here
// mints a feed file; this renders a button and a `<dialog>` offering the feed
// to a reader.
//
// It is OPT-IN BY CALL, not by import. Nothing in this file registers a state,
// a marrow hook or a `[tool.rheo.html]` bundle, so a project that imports
// `@rheo/feeds` for `feed`/`configure`/`items` and never calls `feeds-modal`
// emits exactly what it emitted before this file existed.
//
// That is also why the package still declares NO bundle in `typst.toml`, where
// a reader coming from `@rheo/rookery-search` would expect one. rheo injects an
// imported package's bundle into every consumer of that package, and — worse —
// it stops auto-injecting a project's implicit `style.css`/`index.js` the
// moment any imported package registers a bundle of its own. A consumer that
// had not named its own assets in `rheo.toml` would silently lose them, on
// nothing more than an import. So the modal's CSS and JS ride along inside the
// content this function returns.

// ---- icons -----------------------------------------------------------------
//
// Both are exported: a project supplying its own `options:` entry needs an icon
// to put in it, and `mail-icon` is the one nearly every such entry wants.

#let atom-icon(size: 18) = html.elem(
  "svg",
  attrs: (
    width: str(size),
    height: str(size),
    viewBox: "0 0 24 24",
    fill: "currentColor",
  ),
  html.elem("path", attrs: (
    d: "M19.199 24C19.199 13.467 10.533 4.8 0 4.8V0c13.165 0 24 10.835 24 24h-4.801zM3.291 17.415c1.814 0 3.293 1.479 3.293 3.295 0 1.813-1.485 3.29-3.301 3.29C1.47 24 0 22.526 0 20.71s1.475-3.294 3.291-3.295zM15.909 24h-4.665c0-6.169-5.075-11.245-11.244-11.245V8.09c8.727 0 15.909 7.184 15.909 15.91z",
  )),
)

#let mail-icon(size: 16) = html.elem(
  "svg",
  attrs: (
    width: str(size),
    height: str(size),
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    stroke-width: "2",
  ),
)[
  #html.elem("rect", attrs: (x: "2", y: "4", width: "20", height: "16", rx: "2"))
  #html.elem("path", attrs: (d: "m2 6 10 7 10-7"))
]

// ---- options ---------------------------------------------------------------

// One `<li>`. Shared by the pregiven Atom option and every caller-supplied one,
// so the two cannot drift apart in markup.
#let _option(icon, label, href, desc) = html.elem(
  "li",
  attrs: (class: "subscribe-option"),
)[
  #html.elem("a", attrs: (href: href, class: "subscribe-option-link"))[
    #icon
    #html.elem("span")[#label]
  ]
  #html.elem("p", attrs: (class: "subscribe-option-desc"))[#desc]
]

// Validated on the spot rather than left for the markup to render as something
// odd: a malformed option is a project's own typo, and a build failure naming
// the index it sits at is far easier to act on than a silently empty `<li>`.
#let _expect-option(v, i) = {
  let at = "`options` entry " + str(i)
  assert(
    type(v) == dictionary,
    message: "@rheo/feeds: feeds-modal's " + at + " must be a dictionary with "
      + "`label` and `href` — got " + repr(type(v)),
  )
  for field in ("label", "href") {
    let s = v.at(field, default: none)
    assert(
      type(s) == str and s.len() > 0,
      message: "@rheo/feeds: feeds-modal's " + at + " needs a non-empty `"
        + field + "` string — got " + repr(s),
    )
  }
  v
}

// ---- feeds-modal -----------------------------------------------------------

// A subscribe button and the `<dialog>` it opens, returned as SIBLING content
// in that order — never nested, so a project's header can position the trigger
// without the dialog inheriting the header's own layout or typography.
//
// THE ATOM OPTION IS PREGIVEN. It is always the first entry, and there is no
// argument that removes it: a feeds package whose modal can omit the feed would
// be offering the wrong thing. `feed-path`, `feed-label` and `feed-desc` re-word
// and re-target it, which is all any of the sites this was lifted from needed.
//
// Everything site-specific goes through `options:`, an array of
// `(icon: <content>, label: <str>, href: <str>, desc: <content>)` rendered after
// the Atom entry in array order. `icon` and `desc` are content, so an entry can
// carry any markup — a mailto with a bolded address, a link to a Mastodon
// account, whatever the project actually offers.
#let feeds-modal(
  feed-path: "/feed.xml",
  feed-label: "Atom feed",
  feed-desc: [Pull each new entry into an #html.elem("a", attrs: (
    href: "https://aboutfeeds.com",
    target: "_blank",
    rel: "noopener",
  ))[RSS/Atom reader].],
  options: (),
  button-label: "Subscribe",
  button-title: "Subscribe",
  icon-size: 18,
  id: "subscribe-dialog",
) = {
  assert(
    type(options) == array,
    message: "@rheo/feeds: feeds-modal's `options` must be an array of "
      + "dictionaries — got " + repr(type(options)),
  )
  let extra = options.enumerate().map(((i, o)) => {
    let o = _expect-option(o, i)
    _option(
      o.at("icon", default: none),
      o.label,
      o.href,
      o.at("desc", default: []),
    )
  })

  html.elem("button", attrs: (
    type: "button",
    class: "subscribe-btn",
    title: button-title,
    aria-haspopup: "dialog",
    aria-controls: id,
  ))[
    #atom-icon(size: icon-size)
    #html.elem("span")[#button-label]
  ]

  html.elem("dialog", attrs: (id: id, class: "subscribe-dialog"))[
    // `<form method="dialog">` is what closes the dialog on submit — no script
    // involved, which is why the close button needs none.
    #html.elem("form", attrs: (method: "dialog", class: "subscribe-dialog-close-form"))[
      #html.elem("button", attrs: (type: "submit", class: "dialog-close", aria-label: "Close"))[✕]
    ]
    #html.elem("ul", attrs: (class: "subscribe-options"))[
      #_option(atom-icon(size: icon-size), feed-label, feed-path, feed-desc)
      #extra.join()
    ]
  ]
}
