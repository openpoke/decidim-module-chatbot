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
        validate :validate_workflow_config, if: :enabled?

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

        def workflow_display_name
          workflow_manifest&.title
        end

        private

        def validate_workflow_config
          return unless workflow_manifest&.configurable?

          workflow_manifest.settings_attributes.each do |key, options|
            next unless options[:required]

            next if config[key.to_s].present?

            errors.add(:config, :invalid,
                       message: I18n.t("decidim.chatbot.admin.settings.form.errors.#{key}_blank", default: I18n.t("errors.messages.blank")))
          end
        end
      end
    end
  end
end
