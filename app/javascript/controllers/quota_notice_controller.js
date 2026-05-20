import { Controller } from "@hotwired/stimulus";

// Auto-dismisses the quota notice after 6 seconds with a short fade-out.
export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), 6000);
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout);
  }

  dismiss() {
    this.element.style.transition = "opacity 220ms cubic-bezier(0.32, 0.72, 0, 1)";
    this.element.style.opacity = "0";
    setTimeout(() => this.element.remove(), 240);
  }
}
