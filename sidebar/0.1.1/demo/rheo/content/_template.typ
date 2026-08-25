// The one `#show: sidebar.with(..)` every vertebra applies.
//
// NOTE WHAT IS NOT HERE: no `nav:` array and no `current:`. Both are derived —
// `nav` from the spine tree rheo injects, `current` from the per-page handle it
// publishes. Navigation is shaped by `rheo.toml`, not by a second copy of the
// site structure kept in Typst.
#import "@rheo/sidebar:0.1.1": sidebar

#let template(doc) = {
  show: sidebar.with(title: "Sidebar Demo", home-url: "/", accent-color: "#c9a227")
  doc
}
