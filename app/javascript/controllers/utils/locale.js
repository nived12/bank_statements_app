// Maps the HTML lang attribute to an Intl-compatible locale.
// "es" is Spain (European format); MXN amounts use "es-MX".
export function resolveLocale() {
  return document.documentElement.lang === "es" ? "es-MX" : "en-US"
}
