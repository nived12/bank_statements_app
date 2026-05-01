import { Controller } from "@hotwired/stimulus"

// Registers the browser for web push notifications 30s after page load.
// Requires VAPID_PUBLIC_KEY meta tag in the layout head.
export default class extends Controller {
  connect() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) return;
    if (Notification.permission === "denied") return;

    const vapidKey = document.querySelector('meta[name="vapid-public-key"]')?.content;
    if (!vapidKey) return;

    // Delay prompt to avoid interrupting the user immediately
    this.timer = setTimeout(() => this.#requestPermission(vapidKey), 30_000);
  }

  disconnect() {
    clearTimeout(this.timer);
  }

  async #requestPermission(vapidKey) {
    if (Notification.permission === "granted") {
      await this.#subscribe(vapidKey);
      return;
    }

    const permission = await Notification.requestPermission();
    if (permission === "granted") {
      await this.#subscribe(vapidKey);
    }
  }

  async #subscribe(vapidKey) {
    try {
      const registration = await navigator.serviceWorker.register("/sw.js");
      const existing = await registration.pushManager.getSubscription();

      if (existing) {
        // Only re-send to server if we haven't registered this endpoint before.
        // Avoids a redundant POST on every page load for already-registered browsers.
        const knownEndpoint = localStorage.getItem("vt_push_endpoint");
        if (knownEndpoint !== existing.endpoint) {
          await this.#sendToServer(existing);
        }
        return;
      }

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.#urlBase64ToUint8Array(vapidKey),
      });

      await this.#sendToServer(subscription);
    } catch (err) {
      console.warn("[web-push] subscription failed:", err);
    }
  }

  async #sendToServer(subscription) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    const response = await fetch("/api/v1/devices", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token || "",
        "Authorization": `Bearer ${this.#getAccessToken()}`,
      },
      body: JSON.stringify({
        device: {
          push_token: JSON.stringify(subscription),
          platform: "web",
        },
      }),
    });

    if (response.ok) {
      // Cache the endpoint so we skip redundant server calls on future page loads
      localStorage.setItem("vt_push_endpoint", subscription.endpoint);
    } else {
      console.warn("[web-push] device registration failed:", response.status);
    }
  }

  #getAccessToken() {
    // Access token is stored in sessionStorage by the mobile-web login flow.
    // For web-only users authenticated via Rails session, this returns empty
    // and the API falls back to session authentication (handled by base_controller).
    return sessionStorage.getItem("access_token") || "";
  }

  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    const rawData = atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
}
