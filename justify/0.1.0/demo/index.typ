#import "@rheo/justify:0.1.0": template

#show: template
#set text(font: "DejaVu Serif", size: 22pt)
#set par(justify: true)

// The passage is defined once and rendered in both columns, so the two sides
// are guaranteed to hold identical text — only the justification method differs.
#let paragraphs = (
  [The relationship between typographic colour and reading comfort has been
    studied extensively since the early twentieth century. When lines of
    justified text contain excessive inter-word spacing, the eye perceives pale
    horizontal streaks — "rivers" — that cut vertically through the paragraph,
    disrupting the smooth lateral scanning motion that skilled readers depend
    upon. These rivers are not merely an aesthetic blemish; they constitute a
    measurable impediment to reading speed and comprehension.],
  [Traditional typesetting systems addressed this problem through a combination
    of techniques: hyphenation dictionaries that permitted words to break at
    syllable boundaries, letterspacing adjustments that distributed small amounts
    of additional space between individual characters, and — most significantly —
    global optimization algorithms that evaluated thousands of possible
    line-break combinations to find the arrangement minimizing total spacing
    deviation across the entire paragraph.],
  [The Knuth-Plass algorithm, developed by Donald Knuth and Michael Plass for
    the TeX typesetting system in 1981, remains the gold standard for paragraph
    optimization. Rather than greedily filling each line from left to right, the
    algorithm constructs a graph of all feasible breakpoints and finds the
    shortest path — the combination of breaks that produces the most uniform
    spacing throughout. Even a simplified implementation produces dramatically
    better results than the greedy approach used by web browsers and most word
    processors.],
  [Modern CSS justification operates on a strictly greedy, line-by-line basis:
    the browser fills each line with as many words as will fit, then distributes
    the remaining space uniformly between words. This approach requires no
    lookahead and executes quickly, but it produces wildly inconsistent spacing —
    particularly in narrow columns where a single long word can force enormous
    gaps across the preceding line. The result: rivers of white space that would
    have horrified any compositor working with metal type.],
)

= Knuth–Plass justification, side by side

The same passage justified two ways. Narrow the window to squeeze the columns:
the rivers of white space open up on the right, while the Knuth–Plass side keeps
its spacing even.

#html.elem(
  "div",
  attrs: (class: "compare"),
  {
    // Left: routed through the package. Paragraphs keep the top-level
    // `justify: true`, so the template's show rule wraps each in
    // `<p class="rheo-kp">` and the client runtime lays them out with KP.
    html.elem("div", attrs: (class: "col"), {
      heading(level: 3)[With #raw("@rheo/justify")]
      for p in paragraphs {
        p
        parbreak()
      }
    })
    // Right: identical text, but `justify` is disabled so the show rule passes
    // it straight through to plain `<p>` elements. The demo stylesheet applies
    // `text-align: justify`, giving the browser's own greedy justification.
    html.elem("div", attrs: (class: "col native"), {
      set par(justify: false)
      heading(level: 3)[Native browser]
      for p in paragraphs {
        html.elem("p", p)
      }
    })
  },
)
