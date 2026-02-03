# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      # Form class for the organization welcome workflow settings.
      # Extends SettingForm and adds welcome-specific attributes.
      class WelcomeWorkflowSettingsForm < SettingForm
        mimic :setting

        attribute :delegate_workflow, String
        attribute :custom_text, String

        def map_model(model)
          super
          self.delegate_workflow = config[:delegate_workflow]
          self.custom_text = config[:custom_text]
        end

        # Returns the workflow-specific config hash for saving
        def workflow_config
          {
            delegate_workflow: delegate_workflow,
            custom_text: custom_text
          }.compact_blank
        end

        def delegate_workflow_options
          Decidim::Chatbot.start_workflows_registry.manifests
                          .reject { |manifest| manifest.name == :organization_welcome }
                          .map { |manifest| [manifest.title, manifest.name.to_s] }
        end
      end
    end
  end
end
