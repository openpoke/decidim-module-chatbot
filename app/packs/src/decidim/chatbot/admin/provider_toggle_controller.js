import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = { url: String }
  static csrfToken = document.querySelector('meta[name="csrf-token"]') && document.querySelector('meta[name="csrf-token"]').content

  toggle() {
    const isEnabled = this.checkboxTarget.checked

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this.constructor.csrfToken,
        "Accept": "application/json",
        "Content-Type": "application/json"
      }
    }).catch(() => {
      // Revert on error
      this.checkboxTarget.checked = !isEnabled
    })
  }
}
