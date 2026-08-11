// blogfeed — client-side tag filtering for the index feed.
//
// Auto-injected on every page of an importing site, but inert unless the page
// actually rendered a `.filter-container` (i.e. `filter-bar(...)`). Clicking a
// `.filter-btn` toggles it: posts whose `data-tags` intersect the active set
// stay visible and the rest get `.hidden`. With nothing active, everything shows.
//
// Active filters are colored by click order (1st, 2nd, 3rd, …), not by
// identity, so re-clicking builds a fresh sequence each time. `active` is a
// Set, which iterates in insertion order — since a filter is only ever
// re-added after having been deleted (a toggle, never a double-add), that
// order is exactly the click order.
const ORDER_CLASS_COUNT = 6;

function orderClass(index) {
  return `order-${(index % ORDER_CLASS_COUNT) + 1}`;
}

function setOrderClass(el, index) {
  for (const c of Array.from(el.classList)) {
    if (c.startsWith("order-")) el.classList.remove(c);
  }
  if (index !== -1) el.classList.add(orderClass(index));
}

function initBlogfeed() {
  const buttons = Array.from(document.querySelectorAll(".filter-btn"));
  if (buttons.length === 0) return;

  const items = Array.from(document.querySelectorAll(".post-item"));
  const active = new Set();

  // Attach a tooltip bubble built from each button's data-tooltip.
  for (const button of buttons) {
    const text = button.getAttribute("data-tooltip");
    if (!text) continue;
    const tip = document.createElement("div");
    tip.className = "tooltip";
    tip.textContent = text;
    button.appendChild(tip);
  }

  function apply() {
    const order = Array.from(active);

    for (const item of items) {
      const tags = (item.getAttribute("data-tags") || "")
        .split(" ")
        .filter(Boolean);
      const show = active.size === 0 || tags.some((t) => active.has(t));
      item.classList.toggle("hidden", !show);
    }
    for (const button of buttons) {
      setOrderClass(button, order.indexOf(button.getAttribute("data-filter")));
    }
    // Highlight tag pills whose tag is currently active.
    for (const label of document.querySelectorAll(".tag-label")) {
      const tagClass = Array.from(label.classList).find(
        (c) => c.startsWith("tag-") && c !== "tag-label",
      );
      const tag = tagClass ? tagClass.slice("tag-".length) : null;
      const index = tag !== null ? order.indexOf(tag) : -1;
      label.classList.toggle("active", index !== -1);
      setOrderClass(label, index);
    }
  }

  for (const button of buttons) {
    button.addEventListener("click", () => {
      const filter = button.getAttribute("data-filter");
      button.classList.toggle("active");
      if (button.classList.contains("active")) active.add(filter);
      else active.delete(filter);
      apply();
    });
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initBlogfeed);
} else {
  initBlogfeed();
}
