import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = { url: String }
  
  toggle() {
    const isEnabled = this.checkboxTarget.checked
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json",
        "Content-Type": "application/json"
      }
    }).catch(() => {
      // Revert on error
      this.checkboxTarget.checked = !isEnabled
    })
  }
}
