// blogfeed — client-side tag filtering for the index feed.
//
// Auto-injected on every page of an importing site, but inert unless the page
// actually rendered a `.filter-container` (i.e. `filter-bar(...)`). Clicking a
// `.filter-btn` toggles it: posts whose `data-tags` intersect the active set
// stay visible and the rest get `.hidden`. With nothing active, everything shows.
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
    for (const item of items) {
      const tags = (item.getAttribute("data-tags") || "")
        .split(" ")
        .filter(Boolean);
      const show = active.size === 0 || tags.some((t) => active.has(t));
      item.classList.toggle("hidden", !show);
    }
    // Highlight tag pills whose tag is currently active.
    for (const label of document.querySelectorAll(".tag-label")) {
      const tagClass = Array.from(label.classList).find(
        (c) => c.startsWith("tag-") && c !== "tag-label",
      );
      const tag = tagClass ? tagClass.slice("tag-".length) : null;
      label.classList.toggle("active", tag !== null && active.has(tag));
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
