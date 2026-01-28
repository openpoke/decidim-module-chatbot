import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spaceSelect", "componentsWrapper", "componentSelect", "workflowHeading", "workflowConfig"]
  static values = {
    componentsUrl: String,
    workflowFieldsUrl: String,
    loadingText: String,
    selectSpaceFirstText: String
  }

  connect() {
    this.componentsData = []

    if (this.hasComponentSelectTarget && !this.spaceSelectTarget?.value) {
      this.componentSelectTarget.disabled = true
    }
  }

  async changeWorkflow(event) {
    const workflow = event.target.value

    if (!workflow || !this.hasWorkflowConfigTarget) return

    try {
      const separator = this.workflowFieldsUrlValue.includes("?") ? "&" : "?"
      const url = `${this.workflowFieldsUrlValue}${separator}workflow=${encodeURIComponent(workflow)}`
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) throw new Error("Failed to fetch workflow fields")

      this.workflowConfigTarget.innerHTML = await response.text()
    } catch (error) {
      console.error("Failed to load workflow fields:", error)
    }
  }

  async loadComponents(event) {
    const spaceGid = event.target.value
    const componentSelect = this.componentSelectTarget

    if (!spaceGid) {
      this.hideComponentsWrapper()
      return
    }

    this.showComponentsWrapper()
    componentSelect.disabled = true
    componentSelect.innerHTML = `<option value="">${this.loadingTextValue}</option>`

    try {
      const separator = this.componentsUrlValue.includes('?') ? '&' : '?'
      const url = `${this.componentsUrlValue}${separator}space_gid=${encodeURIComponent(spaceGid)}`
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) throw new Error("Failed to fetch components")

      const components = await response.json()
      this.componentsData = components
      this.renderComponentOptions(componentSelect, components)
    } catch (error) {
      console.error("Failed to load components:", error)
      this.renderEmptySelect(componentSelect)
    }
  }

  renderComponentOptions(select, components) {
    select.innerHTML = ""

    components.forEach((component, index) => {
      const option = document.createElement("option")
      option.value = component.id
      option.textContent = component.name
      option.dataset.manifestName = component.manifest_name
      if (index === 0) option.selected = true
      select.appendChild(option)
    })

    select.disabled = false
  }

  renderEmptySelect(select) {
    select.innerHTML = `<option value="">${this.selectSpaceFirstTextValue}</option>`
    select.disabled = true
  }

  showComponentsWrapper() {
    if (this.hasComponentsWrapperTarget) {
      this.componentsWrapperTarget.style.display = ""
    }
  }

  hideComponentsWrapper() {
    if (this.hasComponentsWrapperTarget) {
      this.componentsWrapperTarget.style.display = "none"
    }
  }
}
