# @rheo/slides

Reveal.js-backed slides for Typst HTML output.

## Usage

```typ
#import "@rheo/slides:0.1.1": template, slide

#show: template.with(
  theme: "black",
  title: "My Presentation",
  first-slide: [
    = My Presentation 
  ],
)

#slide(title: "Intro")[
  == Second slide
  Content here.
]

#slide[
  == Third slide
  Still under the "Intro" title.
]

#slide(title: "Part 2")[
  == Fourth slide
]

#slide(title: none)[
  == Fifth slide
  No title rendered.
]
```

Either `first-slide` or `title` must be provided. When `first-slide` is
omitted, the opening slide defaults to a level-1 heading containing the
`title`.

Pass `title:` on `slide` to render a `<h2 class="slide-title">` at the top of
that section. If `title` is omitted, the previous slide's title carries over;
pass `title: none` to explicitly clear it.

## Dev-server rehydration

Since 0.1.1 an edit under `rheo watch` keeps you on the slide you were reading,
instead of making the page fall back to a full reload.

`rheo watch` morphs an edited page into the live DOM rather than reloading it,
which re-executes no script and hands back the pre-hydration markup. This
package re-applies the theme stylesheet and the title bar afterwards, and tells
Reveal to recount the slides, but deliberately does **not** re-initialise the
deck — initialising again is what would jump you back to slide one.

This needs rheo **0.6.4** or newer, the release that understands
`js_rehydrate`. Under an older rheo the key is ignored and the page reloads as
it did before. Note that rheo surveys *every* script on a page before morphing
and reloads if any one of them has not declared itself, so a page mixing this
package with an unmigrated one still reloads.

On a page with no deck the package now does nothing at all — previously it
appended its stylesheet to `<head>` regardless, which under rehydrate would
have added one copy per edit.
