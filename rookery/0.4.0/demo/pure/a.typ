#import "../../src/lib.typ": idea

= Page A

// The tagged note sits inside a TITLED but UNTAGGED one, which is what makes
// page B's pair of `#ideas-outline` calls demonstrate PRUNE AND PROMOTE: the
// parent shows in the unfiltered index and does not match the filter, so under
// `tags: "phd"` it is pruned and the child re-based to the top level rather than
// left dangling at a depth with no parent above it.
//
// The parent needs a TITLE for that to be visible at all: `_ideas-outline-data`
// skips a note whose title is `none`, so an untitled parent never appears in
// either index and there is nothing to promote past. `paged.typ` still carries
// an untitled auto-id note, so that case stays covered.
//
// The child's two tags also put `idea-tag-phd idea-tag-draft` on its outline row.
#idea(title: [Auto note])[
  An auto-id note on page A.

  #idea("pinned", title: [Pinned], tags: ("phd", "draft"))[
    A pinned note, referenced cross-page from page B.
  ]
]
