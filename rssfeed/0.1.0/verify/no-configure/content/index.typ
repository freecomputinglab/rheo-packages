// Row 7: importing @rheo/rssfeed is enough for rheo to splice its
// `.marrow.typ` into the bundle root (see that file's own header comment),
// but a project that never calls `configure(...)` must still get NO feed XML
// and NO autodiscovery link — `_feeds` defaults to `()`, `_mint-plan(())` is
// `()`, and the marrow's loop mints nothing. `../run.sh` asserts the build
// succeeds with no *.xml in its output and no atom+xml link in this page's
// own <head>.
#import "@rheo/rssfeed:0.1.0"

= No Configure

Imports the package above (so its `.marrow.typ` is in play) but never calls
`configure(...)`.
