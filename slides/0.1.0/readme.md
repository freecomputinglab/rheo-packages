# @rheo/slides

Reveal.js-backed slides for Typst HTML output.

## Usage

```typ
#import "@rheo/slides:0.1.0": template, slide

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
