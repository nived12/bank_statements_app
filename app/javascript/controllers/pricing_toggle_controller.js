import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyBtn", "annualBtn", "monthlyPrice", "annualPrice", "annualSubtext", "annualSavings"]

  connect() {
    this.showMonthly()
  }

  showMonthly() {
    this.monthlyPriceTargets.forEach(el => el.classList.remove("hidden"))
    this.annualPriceTargets.forEach(el => el.classList.add("hidden"))
    this.annualSubtextTargets.forEach(el => el.classList.add("hidden"))
    this.annualSavingsTargets.forEach(el => el.classList.add("hidden"))

    this.monthlyBtnTarget.classList.add("bg-white", "shadow-sm", "text-slate-900")
    this.monthlyBtnTarget.classList.remove("text-slate-500")
    this.annualBtnTarget.classList.remove("bg-white", "shadow-sm", "text-slate-900")
    this.annualBtnTarget.classList.add("text-slate-500")
  }

  showAnnual() {
    this.monthlyPriceTargets.forEach(el => el.classList.add("hidden"))
    this.annualPriceTargets.forEach(el => el.classList.remove("hidden"))
    this.annualSubtextTargets.forEach(el => el.classList.remove("hidden"))
    this.annualSavingsTargets.forEach(el => el.classList.remove("hidden"))

    this.annualBtnTarget.classList.add("bg-white", "shadow-sm", "text-slate-900")
    this.annualBtnTarget.classList.remove("text-slate-500")
    this.monthlyBtnTarget.classList.remove("bg-white", "shadow-sm", "text-slate-900")
    this.monthlyBtnTarget.classList.add("text-slate-500")
  }
}
