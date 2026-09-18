// The one `#show: sidebar.with(..)` every vertebra applies. `sidebar()` takes
// no `ctx:` — it feature-detects via `state("rheo-handle")` and `sys.inputs`.
#import "@rheo/sitemap:0.1.0": sidebar

#let template(doc) = {
  show: sidebar.with(title: "Sitemap Demo", home-url: "/")
  doc
}
