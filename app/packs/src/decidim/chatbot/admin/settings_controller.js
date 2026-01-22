import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spaceSelect", "componentsWrapper", "componentSelect", "actionsWrapper", "actionsSelect"]
  static values = {
    componentsUrl: String,
    actionsUrl: String,
    loadingText: String,
    selectComponentText: String,
    selectActionText: String,
    noActionsText: String,
    selectSpaceFirstText: String
  }

  connect() {
    this.componentsData = []

    if (this.hasComponentSelectTarget && !this.spaceSelectTarget?.value) {
      this.componentSelectTarget.disabled = true
    }
  }

  async loadComponents(event) {
    const spaceGid = event.target.value
    const componentSelect = this.componentSelectTarget

    if (!spaceGid) {
      this.hideComponentsWrapper()
      this.hideActionsWrapper()
      return
    }

    this.showComponentsWrapper()
    this.hideActionsWrapper()
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

  async loadActions(event) {
    const componentId = event.target.value
    if (!componentId) {
      this.hideActionsWrapper()
      return
    }

    this.showActionsWrapper()

    const actionsSelect = this.actionsSelectTarget
    actionsSelect.disabled = true
    actionsSelect.innerHTML = `<option value="">${this.loadingTextValue}</option>`

    try {
      const url = `${this.actionsUrlValue}?component_id=${encodeURIComponent(componentId)}`
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) throw new Error("Failed to fetch actions")

      const actions = await response.json()
      this.renderActionsOptions(actionsSelect, actions)
    } catch (error) {
      console.error("Failed to load actions:", error)
      actionsSelect.innerHTML = `<option value="">${this.noActionsTextValue}</option>`
      actionsSelect.disabled = true
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

  renderActionsOptions(select, actions) {
    select.innerHTML = `<option value="">${this.selectActionTextValue}</option>`

    if (actions.length === 0) {
      select.innerHTML = `<option value="">${this.noActionsTextValue}</option>`
      select.disabled = true
      return
    }

    actions.forEach(action => {
      const option = document.createElement("option")
      option.value = action.id
      option.textContent = action.name
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

  showActionsWrapper() {
    if (this.hasActionsWrapperTarget) {
      this.actionsWrapperTarget.style.display = ""
    }
  }

  hideActionsWrapper() {
    if (this.hasActionsWrapperTarget) {
      this.actionsWrapperTarget.style.display = "none"
    }
    if (this.hasActionsSelectTarget) {
      this.actionsSelectTarget.innerHTML = ''
    }
  }
}
