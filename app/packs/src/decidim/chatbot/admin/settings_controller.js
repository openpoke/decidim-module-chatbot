import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spaceSelect", "componentsWrapper", "componentSelect", "workflowHeading"]
  static values = {
    componentsUrl: String,
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

  updateWorkflowTitle(event) {
    const select = event.target
    const selectedOption = select.options[select.selectedIndex]
    if (this.hasWorkflowHeadingTarget && selectedOption) {
      this.workflowHeadingTarget.textContent = this.configurationForTextValue.replace("%{workflow}", selectedOption.text)
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
      const url = `${this.componentsUrlValue}?space_gid=${encodeURIComponent(spaceGid)}`
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
