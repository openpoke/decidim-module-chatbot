import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { editUrl: String }

  changeWorkflow(event) {
    const workflow = event.target.value
    if (!workflow) return

    const url = new URL(this.editUrlValue, window.location.origin)
    url.searchParams.set("workflow", workflow)
    window.location.href = url.toString()
  }
}
