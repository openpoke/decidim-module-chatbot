import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = { url: String }

  toggle() {
    const isEnabled = this.checkboxTarget.checked
    const csrfMetaTag = document.querySelector('meta[name="csrf-token"]')
    const csrfToken = csrfMetaTag?.content

    if (!csrfToken) {
      this.checkboxTarget.checked = !isEnabled
      return
    }

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json",
        "Content-Type": "application/json"
      }
    }).catch(() => {
      this.checkboxTarget.checked = !isEnabled
    })
  }
}
