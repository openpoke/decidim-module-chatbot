# frozen_string_literal: true

module Decidim
  module Chatbot
    module Admin
      class UpdateSetting < Decidim::Command
        def initialize(form, setting)
          @form = form
          @setting = setting
        end

        def call
          return broadcast(:invalid) if form.invalid?

          update_setting
          broadcast(:ok, setting)
        end

        private

        attr_reader :form, :setting

        def update_setting
          setting.update!(
            start_workflow: form.start_workflow,
            enabled: form.enabled,
            config: sanitized_config
          )
        end

        def sanitized_config
          allowed_keys = form.workflow_manifest&.config_keys || []
          form.config.to_h.slice(*allowed_keys)
        end
      end
    end
  end
end
