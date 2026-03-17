import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.isDown = false
    this.startX = 0
    this.scrollLeft = 0
    this.hasDragged = false

    this._onMouseDown = this.onMouseDown.bind(this)
    this._onMouseUp = this.onMouseUp.bind(this)
    this._onMouseLeave = this.onMouseUp.bind(this)
    this._onMouseMove = this.onMouseMove.bind(this)
    this._onClick = this.onClick.bind(this)

    this.element.addEventListener("mousedown", this._onMouseDown)
    this.element.addEventListener("mouseup", this._onMouseUp)
    this.element.addEventListener("mouseleave", this._onMouseLeave)
    this.element.addEventListener("mousemove", this._onMouseMove)
    this.element.addEventListener("click", this._onClick, true)
  }

  disconnect() {
    this.element.removeEventListener("mousedown", this._onMouseDown)
    this.element.removeEventListener("mouseup", this._onMouseUp)
    this.element.removeEventListener("mouseleave", this._onMouseLeave)
    this.element.removeEventListener("mousemove", this._onMouseMove)
    this.element.removeEventListener("click", this._onClick, true)
  }

  onMouseDown(e) {
    if (e.button !== 0) return
    if (e.target.closest("a, button, input, select, textarea")) return

    this.isDown = true
    this.hasDragged = false
    this.startX = e.pageX - this.element.offsetLeft
    this.scrollLeft = this.element.scrollLeft
    this.element.style.cursor = "grabbing"
    this.element.style.userSelect = "none"
  }

  onMouseUp() {
    if (!this.isDown) return
    this.isDown = false
    this.element.style.cursor = "grab"
    this.element.style.removeProperty("user-select")
  }

  onMouseMove(e) {
    if (!this.isDown) return

    const x = e.pageX - this.element.offsetLeft
    const distance = Math.abs(x - this.startX)

    if (distance > 5) {
      this.hasDragged = true
      e.preventDefault()
    }

    const walk = (x - this.startX) * 1.5
    this.element.scrollLeft = this.scrollLeft - walk
  }

  onClick(e) {
    if (this.hasDragged) {
      e.preventDefault()
      e.stopPropagation()
      this.hasDragged = false
    }
  }
}
