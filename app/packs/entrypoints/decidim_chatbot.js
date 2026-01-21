// Images
require.context("../images", true)

// Stimulus controllers
import { Application } from "@hotwired/stimulus"
import SettingsController from "../src/decidim/chatbot/admin/settings_controller"
import ProviderToggleController from "../src/decidim/chatbot/admin/provider_toggle_controller"

// Use existing Stimulus application or create a new one
const application = window.Stimulus || Application.start()

// Register chatbot admin controllers
application.register("chatbot-settings", SettingsController)
application.register("provider-toggle", ProviderToggleController)
