import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quote", "author"]
  static values = {
    currentIndex: { type: Number, default: 0 },
    quotes: { type: Array, default: [] },
    interval: { type: Number, default: 10000 }
  }

  connect() {
    this.loadQuotes()
    this.waitForQuotesAndShow()
  }

  disconnect() {
    clearInterval(this.rotationTimer)
  }

  loadQuotes() {
    const quotesData = this.element.dataset.quotes

    if (quotesData) {
      try {
        this.quotesValue = JSON.parse(quotesData)
      } catch (e) {
        console.warn("Could not parse quotes data, using defaults")
        this.quotesValue = this.getDefaultQuotes()
      }
    } else {
      this.quotesValue = this.getDefaultQuotes()
    }
  }

  getDefaultQuotes() {
    return [
      { quote: "La mejor inversión que puedes hacer es en ti mismo.", author: "Warren Buffett" },
      { quote: "El inversor individual debe actuar consistentemente como un inversor y no como un especulador.", author: "Benjamin Graham" },
      { quote: "Sabe qué posees y por qué lo posees.", author: "Peter Lynch" },
      { quote: "El tiempo es tu amigo; el impulso es tu enemigo.", author: "John Bogle" },
      { quote: "El dinero grande no está en comprar y vender, sino en esperar.", author: "Charlie Munger" },
      { quote: "Un presupuesto es decirle a tu dinero dónde ir en lugar de preguntarte dónde se fue.", author: "David Ramsey" },
      { quote: "Primero las personas, luego el dinero, luego las cosas.", author: "Suze Orman" },
      { quote: "Los ricos compran activos. Los pobres solo compran gastos.", author: "Robert Kiyosaki" },
      { quote: "Debes ganar control sobre tu dinero o la falta de él te controlará para siempre.", author: "Dave Ramsey" },
      { quote: "La educación formal te dará de vivir; la autoeducación te hará una fortuna.", author: "Jim Rohn" },
      { quote: "Una inversión en conocimiento paga el mejor interés.", author: "Benjamin Franklin" },
      { quote: "Ahorrar dinero es la diferencia entre tu ego y tus ingresos.", author: "Morgan Housel" },
      { quote: "Una parte de todo lo que ganas es tuya para guardar.", author: "George S. Clason" },
      { quote: "Una gran parte de la libertad financiera es tener el corazón y la mente libres de preocupaciones.", author: "Suze Orman" },
      { quote: "La riqueza es más a menudo el resultado de trabajo duro, perseverancia, planificación y autodisciplina.", author: "Thomas J. Stanley" }
    ]
  }

  showQuote() {
    if (this.quotesValue.length === 0) return

    const quote = this.quotesValue[this.currentIndexValue]

    if (this.hasQuoteTarget && this.hasAuthorTarget) {
      this.quoteTarget.textContent = quote.quote
      this.authorTarget.textContent = `— ${quote.author}`
    }
  }

  waitForQuotesAndShow() {
    if (this.quotesValue.length === 0) {
      setTimeout(() => this.waitForQuotesAndShow(), 50)
      return
    }

    this.showRandomQuote()
    this.rotationTimer = setInterval(() => this.showNextQuote(), this.intervalValue)
  }

  showRandomQuote() {
    this.currentIndexValue = Math.floor(Math.random() * this.quotesValue.length)
    this.showQuote()
  }

  showNextQuote() {
    if (!this.hasQuoteTarget || !this.hasAuthorTarget) return

    this.quoteTarget.classList.add("opacity-0", "transition-opacity", "duration-500")
    this.authorTarget.classList.add("opacity-0", "transition-opacity", "duration-500")

    setTimeout(() => {
      this.currentIndexValue = (this.currentIndexValue + 1) % this.quotesValue.length
      this.showQuote()
      this.quoteTarget.classList.remove("opacity-0")
      this.authorTarget.classList.remove("opacity-0")
    }, 500)
  }
}
