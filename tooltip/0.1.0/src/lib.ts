/// <reference types="vite/client" />

import { LitElement, html, css, unsafeCSS } from "lit";
import tippy, { type Instance, type Placement } from "tippy.js";
import tippyCss from "tippy.js/dist/tippy.css?raw";

const PLACEMENTS = new Set<string>([
  "top", "top-start", "top-end",
  "bottom", "bottom-start", "bottom-end",
  "left", "left-start", "left-end",
  "right", "right-start", "right-end",
  "auto", "auto-start", "auto-end",
]);

function isPlacement(s: string): s is Placement {
  return PLACEMENTS.has(s);
}

// Default cap for a preview's popper box. Large enough for a note body,
// small enough to never dominate the viewport on its own. Overridable per
// call via the `max-width` attribute (see my-tooltip.typ's `tooltip(...)`).
const DEFAULT_MAX_WIDTH = "360px";
// Content taller/wider than this fraction of the viewport can't be made to
// fit on ANY side even after `flip` — fall back to a centered overlay rather
// than a popper that still clips off-screen.
const MODAL_FALLBACK_VIEWPORT_RATIO = 0.9;

class TooltipElement extends LitElement {
  static properties = {
    placement: { type: String },
    maxWidth: { type: String, attribute: "max-width" },
  };

  static styles = [
    css`
      :host {
        display: inline-block;
      }
      .content {
        cursor: pointer;
      }
    `,
    unsafeCSS(tippyCss),
    css`
      /* Large rich-content preview: cap width (overridable per instance via
         the maxWidth tippy option below) and scroll vertically rather than
         overflow the viewport or clip content. interactive: true (set below)
         keeps scrolling/clicking inside the preview possible. */
      .tippy-box[data-my-tooltip] .tippy-content {
        max-height: 70vh;
        overflow-y: auto;
      }
      /* Fallback for a preview too large for any side even after flip —
         a centered overlay instead of an off-screen or clipped popper. */
      .my-tooltip-modal-backdrop {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.35);
        z-index: 9998;
      }
      .tippy-box[data-my-tooltip-fallback] {
        position: fixed !important;
        top: 50% !important;
        left: 50% !important;
        transform: translate(-50%, -50%) !important;
        max-width: 90vw;
        max-height: 90vh;
        z-index: 9999;
      }
      .tippy-box[data-my-tooltip-fallback] .tippy-content {
        max-height: 90vh;
      }
    `,
  ];

  placement = "top";
  maxWidth: string | null = null;
  _tippy: Instance | null = null;
  _backdrop: HTMLDivElement | null = null;

  firstUpdated() {
    const anchor = this.renderRoot.querySelector<HTMLSpanElement>(".content");
    const modalSlot = this.renderRoot.querySelector<HTMLSlotElement>('slot[name="modal"]');
    if (!anchor || !modalSlot) return;

    const modalNodes = modalSlot.assignedElements();
    if (modalNodes.length === 0) return;

    const container = document.createElement("div");
    for (const node of modalNodes) {
      container.appendChild(node.cloneNode(true));
    }

    const placement = isPlacement(this.placement) ? this.placement : "auto";
    const isAuto = placement.startsWith("auto");
    const maxWidth = this.maxWidth ?? DEFAULT_MAX_WIDTH;

    this._tippy = tippy(anchor, {
      content: container.innerHTML,
      allowHTML: true,
      placement,
      interactive: true,
      appendTo: "parent",
      maxWidth,
      // Genuinely adaptive placement for "auto"/"auto-start"/"auto-end":
      // flip across all four sides (tippy's default flip only tries the
      // opposite side) and keep the popper within the viewport rather than
      // spilling off it. Explicit placements ("top-end", etc.) are left on
      // tippy's stock popperOptions — their fixed behaviour is unchanged.
      ...(isAuto
        ? {
            popperOptions: {
              modifiers: [
                { name: "flip", options: { fallbackPlacements: ["top", "bottom", "left", "right"] } },
                { name: "preventOverflow", options: { boundary: "viewport", padding: 8 } },
              ],
            },
          }
        : {}),
      onShow: (instance) => {
        instance.popper.setAttribute("data-my-tooltip", "");
        if (!isAuto) return;
        // Measured post-cap, post-position size: if the popper still can't
        // fit within the viewport on any side even after `flip`, no amount
        // of repositioning helps — switch to a centered overlay instead.
        const tooBig =
          instance.popper.offsetWidth > window.innerWidth * MODAL_FALLBACK_VIEWPORT_RATIO ||
          instance.popper.offsetHeight > window.innerHeight * MODAL_FALLBACK_VIEWPORT_RATIO;
        if (!tooBig) return;
        instance.popper.setAttribute("data-my-tooltip-fallback", "");
        const backdrop = document.createElement("div");
        backdrop.className = "my-tooltip-modal-backdrop";
        backdrop.addEventListener("click", () => instance.hide());
        document.body.appendChild(backdrop);
        this._backdrop = backdrop;
      },
      onHide: () => {
        this._backdrop?.remove();
        this._backdrop = null;
      },
    });
  }

  disconnectedCallback() {
    super.disconnectedCallback();
    this._backdrop?.remove();
    this._tippy?.destroy();
  }

  render() {
    return html`
      <span class="content">
        <slot name="content"></slot>
      </span>
      <span hidden>
        <slot name="modal"></slot>
      </span>
    `;
  }
}

class TooltipModal extends HTMLElement {
  connectedCallback() {
    this.slot = "modal";
  }
}

class TooltipContent extends HTMLElement {
  connectedCallback() {
    this.slot = "content";
  }
}

customElements.define("my-tooltip", TooltipElement);
customElements.define("my-tooltip-modal", TooltipModal);
customElements.define("my-tooltip-content", TooltipContent);
