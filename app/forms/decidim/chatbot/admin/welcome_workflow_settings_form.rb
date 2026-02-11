# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      # Form class for the organization welcome workflow settings.
      # Extends SettingForm and adds welcome-specific attributes.
      class WelcomeWorkflowSettingsForm < SettingForm
        mimic :setting

        attribute :custom_text, String

        def map_model(model)
          super
          self.custom_text = config[:custom_text]
        end

        # Returns the workflow-specific config hash for saving
        def workflow_config
          {
            custom_text: custom_text
          }.compact_blank
        end
      end
    end
  end
end
