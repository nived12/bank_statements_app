import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quote", "author"]
  static values = { 
    currentIndex: { type: Number, default: 0 },
    quotes: { type: Array, default: [] }
  }

  connect() {
    this.loadQuotes()
    // Wait for quotes to be loaded before showing random quote
    this.waitForQuotesAndShow()
  }

  disconnect() {
    // No auto-rotation needed
  }

  loadQuotes() {
    // Get quotes from the data attribute or use defaults
    const quotesData = this.element.dataset.quotes
    
    if (quotesData) {
      try {
        this.quotesValue = JSON.parse(quotesData)
      } catch (e) {
        console.warn('Could not parse quotes data, using defaults')
        this.quotesValue = this.getDefaultQuotes()
      }
    } else {
      this.quotesValue = this.getDefaultQuotes()
    }
  }

  getDefaultQuotes() {
    return [
      {
        quote: "La mejor inversión que puedes hacer es en ti mismo.",
        author: "Warren Buffett"
      },
      {
        quote: "El inversor individual debe actuar consistentemente como un inversor y no como un especulador.",
        author: "Benjamin Graham"
      },
      {
        quote: "Sabe qué posees y por qué lo posees.",
        author: "Peter Lynch"
      },
      {
        quote: "El tiempo es tu amigo; el impulso es tu enemigo.",
        author: "John Bogle"
      },
      {
        quote: "El dinero grande no está en comprar y vender, sino en esperar.",
        author: "Charlie Munger"
      },
      {
        quote: "Un presupuesto es decirle a tu dinero dónde ir en lugar de preguntarte dónde se fue.",
        author: "David Ramsey"
      },
      {
        quote: "Primero las personas, luego el dinero, luego las cosas.",
        author: "Suze Orman"
      },
      {
        quote: "Los ricos compran activos. Los pobres solo compran gastos.",
        author: "Robert Kiyosaki"
      },
      {
        quote: "Debes ganar control sobre tu dinero o la falta de él te controlará para siempre.",
        author: "Dave Ramsey"
      },
      {
        quote: "La educación formal te dará de vivir; la autoeducación te hará una fortuna.",
        author: "Jim Rohn"
      }
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
      // If quotes aren't loaded yet, try again in a moment
      setTimeout(() => this.waitForQuotesAndShow(), 50)
      return
    }
    
    // Now show a random quote
    this.showRandomQuote()
  }

  showRandomQuote() {
    // Show a random quote on each page load/refresh
    this.currentIndexValue = Math.floor(Math.random() * this.quotesValue.length)
    this.showQuote()
  }


}
