// @rheo/contents-panel — scroll progress for the contents box.
//
// The MARKUP is not this script's to build. `src/lib.typ` emits the whole
// contents list at compile time, from `query(heading)`, with the hrefs and the
// matching anchor ids already in the page. So a reader with JS off still gets a
// working table of contents — every link is a real fragment link to a real
// anchor — and what this file adds on top is the part that cannot exist without
// a scroll position: which section is being read, and how far through it.
//
// Building the list here instead was the alternative and was not taken: it
// would have put the only copy of the contents behind JS, for a widget whose
// static half is useful on its own.

(function () {
  // The aside is a SIBLING of the article, not its wrapper — `lib.typ` cannot
  // put the document inside a container without breaking any template that
  // sets document metadata. So everything here is found from the aside, and
  // the section anchors are found by id from the document at large.
  const ASIDE = ".rheo-contents-aside";

  function setup(aside) {
    const box = aside.querySelector(".rheo-contents-box");
    const list = aside.querySelector(".rheo-contents-list");
    const links = Array.from(aside.querySelectorAll(".rheo-contents-link"));
    if (!box || !list || links.length === 0) return;

    // Each link's target, resolved once. A link whose anchor is missing is
    // dropped rather than left to throw on every scroll event — that should not
    // happen (lib.typ writes both ends), but a stale cached page can.
    const sections = [];
    for (const link of links) {
      const href = link.getAttribute("href") || "";
      const el = href.startsWith("#") ? document.getElementById(href.slice(1)) : null;
      if (el) {
        sections.push({ link, el, level: parseInt(link.dataset.level, 10) || 1 });
      }
    }
    if (sections.length === 0) return;

    // ---- Adopting the rookery's theme -----------------------------------
    //
    // With `separator: idea`, `contents.css` maps `@rookery/core`'s `--idea-*`
    // palette onto this package's variables. Those properties are inline on
    // the `.idea-box` wrapping each idea, so where the panel is emitted INSIDE
    // one it simply inherits them and there is nothing to do.
    //
    // It is not always inside one. MEASURED: on a weeknote the aside's parent
    // is the week's own `.idea-box` and the mapping resolves to the rookery's
    // green, but on a rookery-MINTED page (`/ideas/<slug>`) the same aside is
    // a child of the page wrapper with no idea box above it, every `--idea-*`
    // lookup falls through to this package's default, and the panel came out
    // blue on a green site.
    //
    // CSS cannot inherit sideways, so the values are copied from an idea that
    // IS on the page — they are identical on all of them, being one theme —
    // onto the aside, where the existing CSS mapping picks them up. Copying
    // the variables rather than the resolved colours keeps the mapping in the
    // stylesheet, where it can be overridden.
    if (aside.classList.contains("rheo-contents-rookery")) {
      const donor = aside.closest("[data-rookery='box']") || document.querySelector("[data-rookery='box']");
      if (donor && donor !== aside) {
        const from = getComputedStyle(donor);
        for (const name of [
          "--idea-date-color",
          "--idea-border-color",
          "--idea-link-color",
          "--idea-fold-color",
          "--idea-label-font",
          "--idea-label-size",
          "--idea-rule-width",
          "--idea-pad",
        ]) {
          const v = from.getPropertyValue(name).trim();
          if (v) aside.style.setProperty(name, v);
        }

        // Two of the hat's metrics are copied RESOLVED rather than as tokens.
        // `--idea-pad` is `0.5em`, and an `em` resolves against the font size
        // of the element that USES it — the idea's box is set larger than this
        // panel, so passing the token through drew a hat 8.8px long against
        // the idea's 12.7px. Copying the computed pixels makes the two the
        // same length whatever either is set in.
        const donorPad = from.paddingLeft;
        if (donorPad && donorPad !== "0px") aside.style.setProperty("--rheo-contents-pad", donorPad);
        const tab = donor.querySelector("[data-rookery='tab']");
        if (tab) {
          const w = getComputedStyle(tab, "::before").width;
          if (w && w !== "auto") aside.style.setProperty("--rheo-contents-hat-width", w);
        }
      }
    }

    // How far down the viewport the header currently reaches. A project with
    // its own header passes its selector as `offset-selector:`; without one
    // nothing overlaps the top of the viewport and the offset is zero.
    //
    // THE HEADER'S BOTTOM EDGE, not its height, and it is recomputed every
    // frame. MEASURED on waterline's weeknotes: the header is `position:
    // sticky; top: 0` inside a `body` with 50px of padding, so at rest its
    // height is 57px but its bottom edge is at 107px — pinning the panel to
    // the height put it 38px INSIDE the header until the reader scrolled. The
    // bottom edge is the number that is correct at both ends: 107 at rest,
    // and 57 once the header has stuck, which is exactly the travel the panel
    // should follow.
    //
    // Clamped at zero so a header that is NOT sticky, and has scrolled away,
    // reads as covering nothing rather than as a negative offset.
    const offsetSelector = box.dataset.offsetSelector || null;
    const offsetBottom = () => {
      const el = offsetSelector ? document.querySelector(offsetSelector) : null;
      return el ? Math.max(0, el.getBoundingClientRect().bottom) : 0;
    };

    // What the panel lines up with before the reader has scrolled — see
    // `align-selector:`. Its viewport position falls as the page scrolls, so
    // taking the LOWER of it and the header offset reproduces exactly what
    // `position: sticky` would do: level with that element at rest, then
    // pinned under the header once it has scrolled past.
    const alignSelector = box.dataset.alignSelector || null;
    const alignTop = () => {
      const el = alignSelector ? document.querySelector(alignSelector) : null;
      if (!el) return null;
      // The target's MIDDLE, not its top. The panel's own hat is centred on
      // the box's top edge — which is what `top` positions — so aligning to
      // the target's top edge left the two hats out by half the target's
      // height. MEASURED against a weeknote: the idea's hat spans 131..150
      // and the panel's sat at 131, about 9px high. The middle is the line
      // the two hats read as sharing.
      const r = el.getBoundingClientRect();
      return r.top + r.height / 2;
    };

    // `--rheo-contents-top-gap` is a CSS length, and only CSS can resolve
    // `rem`/`em` reliably — so it is resolved by measuring a throwaway element
    // of that height, in the panel's own context, rather than by guessing at a
    // root font size. Cached, and recomputed on resize, since it cannot change
    // otherwise.
    let gapPx = null;
    const topGap = () => {
      if (gapPx !== null) return gapPx;
      const token = getComputedStyle(aside).getPropertyValue("--rheo-contents-top-gap").trim();
      if (!token) return (gapPx = 0);
      const probe = document.createElement("div");
      probe.style.cssText = `position:absolute;visibility:hidden;width:0;height:${token}`;
      aside.appendChild(probe);
      gapPx = probe.getBoundingClientRect().height || 0;
      probe.remove();
      return gapPx;
    };

    // Publish it for the stylesheet. On `body`, which is an ancestor of both
    // the box and the anchors, and an inline style so it beats any rule.
    function setTop() {
      // Only meaningful while the panel is pinned. Below the breakpoint it is
      // an ordinary block in the flow and `top` does nothing.
      if (getComputedStyle(aside).position !== "fixed") return;
      if (!offsetSelector && !alignSelector) return;
      // The hat now sits ABOVE the box's top edge, so neither bound can be
      // applied to that edge directly. Both offsets below are MEASURED from
      // the live layout rather than modelled, so they stay right whatever the
      // hat is sized or styled as.
      const asideTop = aside.getBoundingClientRect().top;
      const header = box.querySelector(".rheo-contents-header");
      const title = box.querySelector(".rheo-contents-title");
      // How far the hat overhangs the top of the box.
      const overhang = header ? asideTop - header.getBoundingClientRect().top : 0;
      // Where the title's middle sits relative to that same edge.
      const titleRect = title ? title.getBoundingClientRect() : null;
      const titleMid = titleRect ? titleRect.top + titleRect.height / 2 - asideTop : 0;

      // Pinned: the HAT clears the header, not the box's edge, and clears it
      // by `--rheo-contents-top-gap` rather than sitting flush against it.
      let v = offsetBottom() + overhang + topGap();
      const a = alignTop();
      // At rest: the title's middle sits on the target's middle.
      if (a !== null) v = Math.max(v, a - titleMid);
      document.body.style.setProperty("--rheo-contents-top", v + "px");
    }

    function update() {
      // The header moves as the page scrolls until it sticks, so the panel's
      // offset is re-published here rather than only at load.
      setTop();

      const scrollY = window.scrollY;
      const head = offsetBottom();
      const docHeight = document.documentElement.scrollHeight;
      const top = (el) => el.getBoundingClientRect().top + scrollY - head;

      // The reading position: the point a heading must pass to count as the
      // section being read. At the foot of the page nothing further can scroll,
      // so read the last section as still in progress rather than leaving it
      // stuck part-filled.
      // `top()` has already subtracted the header, so the reading position
      // must not subtract it again — adding it here once double-counted it and
      // pushed the trigger line a header's height too far down the page.
      const atBottom = scrollY + window.innerHeight >= docHeight - 5;
      const pos = atBottom ? docHeight - 1 : scrollY + 50;

      // The page's own progress, behind the title: how far the reader is
      // through the whole document, which no single section's fill reports.
      const scrollable = docHeight - window.innerHeight;
      const pageProgress = scrollable > 0 ? Math.min(Math.max(scrollY / scrollable, 0), 1) : 1;
      box.style.setProperty("--rheo-contents-page-progress", pageProgress * 100 + "%");

      let activeLink = null;
      sections.forEach((section, i) => {
        // A section runs until the next heading at the same depth or
        // shallower. That is what keeps a top-level heading active, and still
        // filling, while its own subsections scroll past.
        let end = docHeight;
        for (let j = i + 1; j < sections.length; j++) {
          if (sections[j].level <= section.level) {
            end = top(sections[j].el);
            break;
          }
        }
        const start = top(section.el);
        const span = Math.max(end - start, 1);
        const progress = Math.min(Math.max((pos - start) / span, 0), 1);
        const active = pos >= start && pos < end;

        section.link.classList.toggle("passed", pos >= end);
        section.link.classList.toggle("active", active);
        section.link.style.setProperty("--rheo-contents-progress", progress * 100 + "%");
        if (active) activeLink = section.link;
      });

      // A contents list longer than its own max height scrolls inside the box,
      // so keep the active row in view — without moving the page, which is what
      // `scrollIntoView` would do.
      if (activeLink && list.scrollHeight > list.clientHeight) {
        list.scrollTo({
          top: activeLink.offsetTop - list.clientHeight / 2 + activeLink.offsetHeight / 2,
          behavior: "smooth",
        });
      }
    }

    function scrollTo(el) {
      window.scrollTo({
        top: el.getBoundingClientRect().top + window.scrollY - offsetBottom() - 20,
        behavior: "smooth",
      });
    }

    for (const { link, el } of sections) {
      link.addEventListener("click", (e) => {
        e.preventDefault();
        scrollTo(el);
        // The fragment still belongs in the url — the smooth scroll is a
        // presentation detail and should not cost the reader a shareable link
        // to the section they are on.
        history.replaceState(null, "", link.getAttribute("href"));
      });
    }

    const toTop = box.querySelector(".rheo-contents-top");
    if (toTop) {
      toTop.addEventListener("click", (e) => {
        e.preventDefault();
        window.scrollTo({ top: 0, behavior: "smooth" });
      });
    }

    // Scroll fires far more often than a frame renders, and `update` reads
    // layout for every section. Coalesce to one pass per frame.
    let queued = false;
    const onScroll = () => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        update();
      });
    };

    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", () => {
      gapPx = null;
      setTop();
      onScroll();
    });
    setTop();
    update();
  }

  const start = () => document.querySelectorAll(ASIDE).forEach(setup);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
