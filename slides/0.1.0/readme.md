# @rheo/slides

Reveal.js-backed slides for Typst HTML output.

## Usage

```typ
#import "@rheo/slides:0.1.0": template, slide

#show: template.with(
  theme: "black",
  first-slide: [
    = My Presentation 
  ],
)

#slide[
  == Second slide
  Content here.
]
```

`first-slide` is required and becomes the opening slide.
