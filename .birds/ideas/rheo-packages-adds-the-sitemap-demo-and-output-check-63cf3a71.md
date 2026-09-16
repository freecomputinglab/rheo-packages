---
id: rheo-packages-adds-the-sitemap-demo-and-output-check-63cf3a71
short-id: '6'
title: Adds the sitemap demo and output check
priority: 3
labels:
- sitemap-package
deps:
- blocked-by:rheo-packages-bundles-the-sitemap-package-js-c082649e
- blocked-by:rheo-packages-scopes-the-sidebar-css-to-a-wrapper-c073075b
closed: false
---
Touches: sitemap/0.1.0/demo/rheo/rheo.toml, sitemap/0.1.0/demo/rheo/content, sitemap/0.1.0/demo/rheo/check.sh, sitemap/0.1.0/Justfile

# What and why

`@rheo/sitemap` (`/home/lox/code/_fcl/rheo-packages/sitemap/0.1.0/`) now exports three
spine-derived views — `sitemap` (the tree), `blogfeed` (the post list) and `sidebar`
(the page template) — all built on one shared walk in `src/core.typ`. None of them is
covered by anything that runs. Every one of them derives its content from rheo rather
than from its call site, so a regression compiles clean and ships a wrong site: an empty
nav, a post list linking to pages that do not exist, a tree whose rules point at the
wrong parent.

This bird adds the demo project and the output assertions, modelled closely on
`sidebar/0.1.1/demo/` — read `sidebar/0.1.1/demo/rheo/rheo.toml` and
`sidebar/0.1.1/demo/rheo/check.sh` in full first, and keep their shape: a small content
tree, a `check.sh` of shell greps plus one `python3` heredoc, `set -euo pipefail`, a
`note()` helper, and a non-zero exit on any failure.

# Steps

1. `sitemap/0.1.0/demo/rheo/rheo.toml`, following `sidebar/0.1.1/demo/rheo/rheo.toml`:
   `version = "0.6.0"`, a `title`, and `[spine] exclude = ["_template.typ"]`.

2. `sitemap/0.1.0/demo/rheo/content/` — a tree deep enough that the walk has something
   to say. Exactly this shape, so the assertions below have fixed targets:

   - `index.typ` — applies the sidebar template and calls `#sitemap(ctx: rheo-context())`.
   - `_template.typ` — the shared `#show: sidebar.with(ctx: rheo-context())` application,
     imported by each page (this is the library the `exclude` above keeps off the spine).
   - `posts/index.typ` — calls `#blogfeed(meta: e => date-cell(...))`.
   - `posts/first.typ`, `posts/second.typ` — each with `#set document(title: .., date: ..,
     keywords: ("typst",))` so they are dated posts with tags.
   - `guide/` with NO `index.typ`, holding `guide/deep.typ`. This is the group node case:
     a directory with no landing page, which the tree must name as `guide/` and NOT link.
     It is the case most likely to regress, because it is the only node whose name is
     read off the first path found beneath it.

   Give one page a `#set document(title: ..)` that differs from its file stem (e.g.
   `posts/first.typ` titled "The first post") and one whose title merely restates its
   stem, so the "print a title only where it says something the file does not" rule has
   both a positive and a negative case.

3. `sitemap/0.1.0/demo/rheo/check.sh` (`chmod +x`), asserting on `build/html`:

   - Every expected page exists: `index.html`, `posts/index.html`, `posts/first.html`,
     `posts/second.html`, `guide/deep.html`.
   - THE TREE: `index.html` contains a `div` with class `sitemap`, one `.sitemap-row`
     per page plus one for the root, a `.sitemap-dir` cell whose text is `guide/` and
     which is NOT inside an `<a>`, and a `.sitemap-name` link to `guide/deep.html`.
   - THE TITLE RULE: `index.html` contains "The first post" in a `.sitemap-title`, and
     the page whose title restates its stem contributes NO `.sitemap-title`.
   - THE FEED: `posts/index.html` contains a `ul.post-list` with exactly two
     `li.post-item`, newest first, and each `a.post-link` href RESOLVES from
     `posts/index.html` — i.e. it is `first.html`, not `posts/first.html`. This is the
     relative-url fix the blogfeed port made; a root-relative href would 404 here and
     the old package's default would have produced one.
   - THE NAV: every page contains a `.sidebar` whose links resolve from the page they
     appear on (`../` prefixes where the page is nested), and the current page's entry
     carries whatever active-state class the template emits.
   - THE BUNDLE: the built `dist/lib.js` is referenced from the emitted HTML and the
     stylesheet is linked once.

4. `sitemap/0.1.0/Justfile` — add the two recipes, matching `sidebar/0.1.1/Justfile`:

   ```
   demo:
       rheo compile demo/rheo

   check: build demo
       ./demo/rheo/check.sh
   ```

5. Add `sitemap/0.1.0/demo/rheo/build/` to `sitemap/0.1.0/.gitignore` if the other
   packages ignore their demo output; check `sidebar/0.1.1/.gitignore` and match it
   exactly rather than guessing.

# Honest uncertainty

`rheo` must be on `PATH` and at version 0.6.0 or newer for `just demo` to work — the
spine tree and the metadata beacon this package reads do not exist below that, and on an
older rheo they fail SILENTLY rather than erroring (this repo's `feeds` package
documents the same trap). If `rheo --version` reports below 0.6.0 or the binary is
missing, stop and record that in the flight notes rather than adapting the demo to an
older shape.

# Non-goals

- No changes to `src/` in this bird. If an assertion fails because of a bug in the
  package, record it in the flight notes; do not widen this bird into a fix unless the
  fix is a one-line typo.
- No CI wiring. This check runs locally, like `feeds`'s.
- Do not touch `blogfeed/0.1.1/`, `sidebar/0.1.1/`, or anything in
  `/home/lox/code/waterline`.

# VERIFY

1. `cd /home/lox/code/_fcl/rheo-packages/sitemap/0.1.0 && just check` exits 0.
2. Deliberately break the walk — in `src/core.typ`, make `segment` return `"?"`
   unconditionally — re-run `just check`, and confirm it FAILS with a named assertion.
   Restore the file afterwards and re-run `just check` to confirm it passes again. A
   check that cannot fail is the failure mode this bird exists to avoid.
3. `ls demo/rheo/build/html/guide/deep.html` exists after `just demo`.