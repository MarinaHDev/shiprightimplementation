import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "event", "submit", "counter"]

  connect() {
    this.refresh()
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => { cb.checked = checked })
    this.refresh()
  }

  refresh() {
    const selected = this.checkboxTargets.filter(cb => cb.checked).length
    const eventChosen = this.hasEventTarget && this.eventTarget.value !== ""

    this.counterTarget.textContent = `${selected} selected`
    this.submitTarget.disabled = !(selected > 0 && eventChosen)

    if (this.hasSelectAllTarget) {
      const total = this.checkboxTargets.length
      this.selectAllTarget.checked = total > 0 && selected === total
      this.selectAllTarget.indeterminate = selected > 0 && selected < total
    }
  }
}
