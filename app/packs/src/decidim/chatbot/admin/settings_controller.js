import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spaceSelect", "componentsWrapper", "componentSelect", "workflowHeading", "workflowConfig"]
  static values = {
    componentsUrl: String,
    workflowFieldsUrl: String,
    loadingText: String,
    selectComponentText: String,
    selectSpaceFirstText: String,
    configurationForText: String
  }

  connect() {
    this.componentsData = []

    if (this.hasComponentSelectTarget && !this.spaceSelectTarget?.value) {
      this.componentSelectTarget.disabled = true
    }
  }

  async changeWorkflow(event) {
    const select = event.target
    const selectedOption = select.options[select.selectedIndex]
    const workflow = select.value

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

      const html = await response.text()

      if (html.trim()) {
        const heading = this.configurationForTextValue.replace("%{workflow}", selectedOption.text)
        this.workflowConfigTarget.innerHTML = `
          <div class="card">
            <div class="card-divider">
              <h2 class="card-title" data-chatbot-settings-target="workflowHeading">${heading}</h2>
            </div>
            <div class="card-section">${html}</div>
          </div>
        `
      } else {
        this.workflowConfigTarget.innerHTML = ""
      }
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
    select.innerHTML = `<option value="">${this.selectComponentTextValue}</option>`

    components.forEach(component => {
      const option = document.createElement("option")
      option.value = component.id
      option.textContent = component.name
      option.dataset.manifestName = component.manifest_name
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
