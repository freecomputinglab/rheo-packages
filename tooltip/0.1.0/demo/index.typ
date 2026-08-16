#import "@rheo/tooltip:0.1.0": tooltip, tooltip-modal, tooltip-content

= Tooltip demo

Explicit placement, unchanged behavior:

#tooltip(placement: "top-end")[
  #tooltip-content[hover me (top-end)]
  #tooltip-modal[A short tip.]
]

Adaptive placement with a rich, multi-block preview (heading, list, math):

#tooltip(placement: "auto")[
  #tooltip-content[hover me (auto, rich)]
  #tooltip-modal[
    == A note preview

    Some body text, followed by a list:

    - first point
    - second point

    And a block equation: $ x^2 + y^2 = z^2 $
  ]
]

Adaptive placement with an overridden `max-width`:

#tooltip(placement: "auto", max-width: "480px")[
  #tooltip-content[hover me (auto, 480px)]
  #tooltip-modal[
    A wider preview than the package default, via `max-width: "480px"`.
  ]
]
