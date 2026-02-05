# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      class SettingForm < Decidim::Form
        mimic :setting

        attribute :enabled, Boolean, default: false
        attribute :start_workflow, String
        attribute :config, Hash, default: {}

        validates :start_workflow, presence: true

        def map_model(model)
          self.enabled = model.enabled?
          self.start_workflow = model.start_workflow
          self.config = (model.config || {}).with_indifferent_access
        end

        def available_workflows
          Decidim::Chatbot.start_workflows_registry.manifests.map do |manifest|
            [manifest.title, manifest.name.to_s]
          end
        end

        def workflow_manifest
          @workflow_manifest ||= Decidim::Chatbot.start_workflows_registry.find(start_workflow)
        end

        # Returns the workflow-specific config hash for saving.
        # Override in workflow-specific forms to provide custom config.
        def workflow_config
          {}
        end
      end
    end
  end
end
