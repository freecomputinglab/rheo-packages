// The active option, shared by the bar and the modal: exactly one row of a
// `role="listbox"` marked, and the `role="combobox"` input told which.

// ---- The active option, shared by the bar and the modal --------------------
//
// ONE implementation for both surfaces, because it is one job: mark exactly one
// row of a `role="listbox"` as the active option, tell the `role="combobox"`
// input which one that is, and keep it in view. The two differ only in what
// FOLLOWS a selection — the modal repaints its preview pane, the bar does
// nothing — so that is the parameter.
//
// It was the modal's alone (`wireModal`'s `select`) while the bar had no keyboard
// navigation at all: the bar announced the full combobox pattern
// (`role="combobox"`, `aria-autocomplete="list"`, `aria-expanded`,
// `aria-controls`) over rows carrying `role="option"`, and then answered no arrow
// key, set `aria-selected` on nothing, and never named an active descendant. A
// reader who tabbed in and typed could only reach a result by tabbing through
// every one of them, with nothing to say which was current.
//
// `-1` MEANS NO ACTIVE OPTION, and it is a real state rather than a sentinel for
// zero. The modal opens on a selected first row, because its preview pane needs
// something to show and an empty pane beside a full list reads as broken. The bar
// must NOT: its dropdown appears under a field the reader is still typing in, and
// pre-highlighting a row there would claim Enter goes somewhere before they have
// looked. So the bar clears to `-1` on every render and the first ArrowDown lands
// on row 0.
//
// CLAMPED, NEVER WRAPPED, at both ends: arrowing past the last row keeps the last
// row rather than jumping to the first. A wrap in a list whose length changes on
// every keystroke loses the reader's place. From `-1`, ArrowUp clamps to row 0
// too — the first press activates the list either way, which is more predictable
// than "up from nothing means the end".
//
// `aria-activedescendant` is on the INPUT, which is where the combobox pattern
// puts it and the only place it can be: focus never leaves the field on either
// surface, so a screen reader learns the current option from this attribute or
// not at all. That needs per-row ids, which cannot live in the markup — a bar is
// placeable more than once on a page — so they are assigned here from the list's
// own id, itself assigned at runtime for the same reason.
let listSeq = 0;
export const selection = (list, input, onSelect = null) => {
  if (list.id === "") list.id = `rookery-search-list-${listSeq++}`;
  let selected = -1;

  const rows = () => list.querySelectorAll(".rookery-search-row");

  // Selecting nothing: the attribute is REMOVED rather than set empty, because an
  // empty `aria-activedescendant` is a reference to an element with no id rather
  // than the absence of one.
  const clear = () => {
    selected = -1;
    input.removeAttribute("aria-activedescendant");
    for (const el of rows()) {
      el.setAttribute("aria-selected", "false");
      el.removeAttribute("data-rookery-search-selected");
    }
  };

  const select = (i) => {
    const els = rows();
    if (els.length === 0) {
      clear();
      return;
    }
    selected = Math.max(0, Math.min(i, els.length - 1));
    for (const [idx, el] of els.entries()) {
      el.id = `${list.id}-opt-${idx}`;
      if (idx === selected) {
        el.setAttribute("aria-selected", "true");
        el.setAttribute("data-rookery-search-selected", "true");
      } else {
        el.setAttribute("aria-selected", "false");
        el.removeAttribute("data-rookery-search-selected");
      }
    }
    input.setAttribute("aria-activedescendant", els[selected].id);
    els[selected].scrollIntoView({ block: "nearest" });
    if (onSelect !== null) onSelect();
  };

  return {
    select,
    clear,
    // `selected + d` through `select`, so the clamp is in one place.
    move: (d) => select(selected + d),
    index: () => selected,
    current: () => rows()[selected] ?? null,
  };
};
